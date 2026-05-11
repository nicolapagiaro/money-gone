# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module MoneyGone
  class LlmClient
    class UnavailableError < StandardError; end
    class ResponseError < StandardError; end

    def initialize(base_url:, model:, timeout_s: 60)
      @base_url = base_url.to_s.chomp("/")
      @model = model
      @timeout_s = timeout_s
    end

    attr_reader :base_url, :model, :timeout_s

    def parse_json(text)
      JSON.parse(text)
    end

    # OpenAI-compatible chat; returns assistant message text.
    def chat(messages, temperature: 0.35)
      body = {
        "model" => model,
        "messages" => messages.map { |m| stringify_message(m) },
        "temperature" => temperature,
        "stream" => false
      }
      json = post_json("chat/completions", body)
      extract_assistant_text(json)
    end

    def categorize(tx, allowed_categories:, include_suggestions: false)
      user = format_transaction_for_prompt(tx)
      categories_line = allowed_categories.join(", ")

      system, user_block, temp = if include_suggestions
        [system_prompt_full(categories_line), user_block_full(user, categories_line), 0.28]
      else
        [system_prompt_fast(categories_line), user_block_fast(user, categories_line), 0.2]
      end

      messages = [
        { role: "system", content: system },
        { role: "user", content: user_block }
      ]
      text = chat(messages, temperature: temp)
      normalized = extract_json_object(text)
      hash = parse_json(normalized)
      hash["suggested_new_category"] = nil if hash["suggested_new_category"].to_s.strip.empty?
      hash["rationale_short"] = nil if hash["rationale_short"].to_s.strip.empty?
      hash
    rescue JSON::ParserError => e
      raise ResponseError, "invalid JSON from model: #{e.message}; raw=#{defined?(text) ? text.to_s[0, 400] : ''}"
    end

    # Testo grezzo (PDF/OCR) → righe canoniche per Normalizer: booking_date, amount_raw, description_raw.
    def parse_statement_transactions(text)
      messages = [
        { role: "system", content: statement_parse_system_prompt },
        { role: "user", content: statement_parse_user_prompt(text) }
      ]
      raw = chat(messages, temperature: 0.12)
      normalized = extract_json_object(raw)
      hash = parse_json(normalized)
      rows = hash["transactions"]
      unless rows.is_a?(Array)
        raise ResponseError,
              "missing or invalid \"transactions\" array in LM response; raw=#{raw.to_s[0, 400]}"
      end

      rows.each_with_index.map do |row, i|
        normalize_statement_row!(row, index: i)
      end
    rescue JSON::ParserError => e
      raise ResponseError,
            "invalid JSON from model (statement parse): #{e.message}; raw=#{raw.to_s[0, 400]}"
    end

    def ping
      get_json("models")
    end

    private

    def system_prompt_fast(categories_line)
      <<~PROMPT.strip
        Sei un assistente che classifica movimenti bancari italiani in una di poche categorie di spesa/risparmio fisse.

        Leggi data, importo (negativo = uscita dal conto) e descrizione; scegli l'etichetta più adatta tra quelle ammesse.
        Se nessuna categoria calza bene, usa "Altro" solo se compare nell'elenco sotto.

        Rispondi SOLO con questo JSON valido, senza testo prima o dopo e senza markdown:
        {"category":"...","confidence":0.xx}

        Regole:
        - "category": copia ESATTAMENTE una di queste etichette: #{categories_line}
          (unica eccezione: puoi ignorare solo maiuscole/minuscole).
        - "confidence": numero tra 0 e 1 (quanto sei sicuro).
        - Non aggiungere altri campi, spiegazioni o ragionamento visibile.
      PROMPT
    end

    def user_block_fast(user, categories_line)
      <<~USER.strip
        Etichette ammesse: #{categories_line}

        Movimento da classificare:
        #{user}
      USER
    end

    def system_prompt_full(categories_line)
      <<~PROMPT.strip
        Sei un assistente per classificare movimenti bancari in italiano.

        Rispondi SOLO con un unico oggetto JSON valido (nessun testo fuori dal JSON, niente markdown).

        Campi obbligatori:
        - "category": stringa identica a UNA delle etichette elencate dall'utente sotto "Categorie ammesse".
          Copia l'etichetta esattamente come scritta (stesse parole, punteggiatura; puoi ignorare solo differenze di maiuscole/minuscole).
        - "confidence": numero tra 0 e 1 (quanto sei sicuro della scelta).
        - "rationale_short": una frase breve in italiano che spiega perché.
        - "suggested_new_category": stringa o null.
          Usalo in due casi: (1) la categoria corretta non c'è nell'elenco — scegli la più simile in "category" e qui proponi il nome più utile;
          (2) anche se la categoria scelta va bene, puoi proporre un nome più specifico per il futuro (es. "Discount" vs supermercato generico).

        Se il movimento non è una spesa/uso chiaro, usa "Altro" solo se presente tra le ammesse.
      PROMPT
    end

    def user_block_full(user, categories_line)
      <<~USER.strip
        Categorie ammesse: #{categories_line}

        Movimento da classificare:
        #{user}
      USER
    end

    def statement_parse_system_prompt
      <<~PROMPT.strip
        Sei un assistente che estrae movimenti da estratti conto italiani in formato testo (anche rumoroso per OCR).

        Rispondi SOLO con un unico oggetto JSON valido (nessun markdown, nessun testo fuori dal JSON).

        Schema obbligatorio:
        {"transactions":[{"booking_date":"YYYY-MM-DD","amount_raw":"...","description_raw":"..."}, ...]}

        Regole:
        - "booking_date": data contabile del movimento in formato ISO YYYY-MM-DD.
        - "amount_raw": importo come stringa in stile italiano (virgola decimale, punto migliaia opzionale).
          Segno: negativo = uscita dal conto, positivo = entrata (come sul PDF/banca).
        - "description_raw": causale o descrizione leggibile, senza ripetere intestazioni di tabella.
        - Ignora totali, saldi iniziali/finali, intestazioni, pagine vuote, note legali: solo righe di movimento.
        - Se non ci sono movimenti: {"transactions":[]}.
      PROMPT
    end

    def statement_parse_user_prompt(text)
      <<~USER.strip
        Estrai tutti i movimenti dal seguente testo (può contenere marker "--- Pagina N ---"):

        #{text}
      USER
    end

    def normalize_statement_row!(row, index:)
      unless row.is_a?(Hash)
        raise ResponseError, "transactions[#{index}] must be an object"
      end

      sym = row.each_with_object({}) do |(k, v), acc|
        key = k.to_s.downcase.tr(" ", "_").to_sym
        acc[key] = v
      end

      date = sym[:booking_date] || sym[:data] || sym[:data_operazione]
      amount = sym[:amount_raw] || sym[:importo] || sym[:importo_eur]
      desc = sym[:description_raw] || sym[:descrizione] || sym[:causale]

      {
        booking_date: date.to_s.strip,
        amount_raw: amount.to_s.strip,
        description_raw: desc.to_s.strip
      }
    end

    def stringify_message(m)
      h = m.transform_keys(&:to_s)
      out = {}
      out["role"] = h["role"] if h["role"]
      out["content"] = h["content"] if h.key?("content")
      out["name"] = h["name"] if h["name"]
      out
    end

    # Try whole string, then strip ```json fences, then first {...} span.
    def extract_json_object(text)
      raw = text.to_s.strip
      return "{}" if raw.empty?

      begin
        parse_json(raw)
        return raw
      rescue JSON::ParserError
        # fall through
      end

      if raw.start_with?("```")
        raw = raw.sub(/\A```(?:json)?\s*/i, "").sub(/\s*```\z/, "").strip
        return raw
      end

      if (m = raw.match(/\{.*\}/m))
        return m[0]
      end

      raw
    end

    def format_transaction_for_prompt(tx)
      <<~TXT.strip
        id: #{tx[:id]}
        banca: #{tx[:bank_id]}
        data: #{tx[:booking_date]}
        importo (segno contabile, negativo = uscita): #{tx[:amount_signed]}
        descrizione: #{tx[:description_clean] || tx[:description_raw]}
      TXT
    end

    def extract_assistant_text(json)
      choice = json["choices"]&.first
      content = choice&.dig("message", "content")
      raise ResponseError, "missing choices[0].message.content in LM response" if content.nil? || content.to_s.strip.empty?

      content.to_s
    end

    def post_json(path, payload)
      uri = endpoint_uri(path)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = timeout_s
      http.read_timeout = timeout_s
      req = Net::HTTP::Post.new(uri)
      req["Content-Type"] = "application/json"
      req.body = JSON.generate(payload)
      res = http.request(req)
      raise_unavailable_or_error!(req, res)
      JSON.parse(res.body)
    rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, Errno::EHOSTUNREACH, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
      raise UnavailableError, e.message
    end

    def get_json(path)
      uri = endpoint_uri(path)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = timeout_s
      http.read_timeout = timeout_s
      req = Net::HTTP::Get.new(uri)
      res = http.request(req)
      raise_unavailable_or_error!(req, res)
      JSON.parse(res.body)
    rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, Errno::EHOSTUNREACH, SocketError, Net::OpenTimeout, Net::ReadTimeout => e
      raise UnavailableError, e.message
    end

    def endpoint_uri(path)
      p = path.sub(%r{\A/}, "")
      URI.parse("#{base_url}/#{p}")
    end

    def raise_unavailable_or_error!(_req, res)
      code = res.code.to_i
      case code
      when 200, 201
        return
      when 0
        raise UnavailableError, "empty HTTP response"
      when 401, 403, 404, 502, 503
        raise UnavailableError, "HTTP #{code}: #{res.body.to_s[0, 500]}"
      else
        raise ResponseError, "HTTP #{code}: #{res.body.to_s[0, 500]}"
      end
    end
  end
end
