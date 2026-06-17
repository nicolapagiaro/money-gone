# frozen_string_literal: true

require "json"
require "ruby_llm"

module MoneyGone
  class LlmClient
    class UnavailableError < StandardError; end
    class ResponseError < StandardError; end

    UNAVAILABLE_ERRORS = [
      RubyLLM::ServiceUnavailableError,
      RubyLLM::UnauthorizedError,
      RubyLLM::ForbiddenError
    ].freeze

    NETWORK_ERRORS = [
      Faraday::ConnectionFailed,
      Faraday::TimeoutError,
      Errno::ECONNREFUSED,
      Errno::ETIMEDOUT,
      Errno::EHOSTUNREACH,
      SocketError
    ].freeze

    def initialize(base_url:, model:, timeout_s: 60)
      @base_url = base_url.to_s.chomp("/")
      @model = model
      @timeout_s = timeout_s
      @llm_context = build_llm_context
    end

    attr_reader :base_url, :model, :timeout_s

    def parse_json(text)
      JSON.parse(text)
    end

    # OpenAI-compatible chat; returns assistant message text.
    def chat(messages, temperature: 0.35)
      msgs = messages.map { |m| normalize_message(m) }
      session = llm_chat(temperature: temperature)
      prior = msgs[0...-1]
      last = msgs[-1]
      prior.each { |m| session.add_message(role: m[:role], content: m[:content]) }

      response =
        if last && last[:role] == :user
          session.ask(last[:content])
        else
          msgs.each { |m| session.add_message(role: m[:role], content: m[:content]) }
          session.complete
        end

      text = extract_content(response)
      raise ResponseError, "empty response from model" if text.strip.empty?

      text
    rescue *UNAVAILABLE_ERRORS, *NETWORK_ERRORS => e
      raise UnavailableError, e.message
    rescue RubyLLM::Error => e
      raise ResponseError, e.message
    end

    def categorize(tx, allowed_categories:, include_suggestions: false)
      user = format_transaction_for_prompt(tx)
      categories_line = allowed_categories.join(", ")

      system, user_block, temp, schema = if include_suggestions
        [system_prompt_full(categories_line), user_block_full(user, categories_line), 0.28, categorization_schema_full]
      else
        [system_prompt_fast(categories_line), user_block_fast(user, categories_line), 0.2, categorization_schema_fast]
      end

      session = llm_chat(temperature: temp).with_schema(schema)
      session.add_message(role: :system, content: system)
      response = session.ask(user_block)
      hash = normalize_categorization_hash(response.content)
      hash
    rescue JSON::ParserError => e
      raw = defined?(response) ? extract_content(response).to_s[0, 400] : ""
      raise ResponseError, "invalid JSON from model: #{e.message}; raw=#{raw}"
    rescue *UNAVAILABLE_ERRORS, *NETWORK_ERRORS => e
      raise UnavailableError, e.message
    rescue RubyLLM::Error => e
      raise ResponseError, e.message
    end

    def ping
      provider = RubyLLM::Providers::OpenAI.new(@llm_context.config)
      models = provider.list_models
      { "data" => models.map { |m| { "id" => m.id } } }
    rescue *UNAVAILABLE_ERRORS, *NETWORK_ERRORS => e
      raise UnavailableError, e.message
    rescue RubyLLM::Error => e
      raise ResponseError, e.message
    end

    private

    def build_llm_context
      RubyLLM.context do |config|
        config.openai_api_key = ENV.fetch("OPENAI_API_KEY", "lm-studio")
        config.openai_api_base = base_url
        config.request_timeout = timeout_s
        config.max_retries = 0
      end
    end

    def llm_chat(temperature:)
      @llm_context.chat(model: model, provider: :openai, assume_model_exists: true)
                  .with_temperature(temperature)
    end

    def normalize_message(message)
      h = message.transform_keys(&:to_s)
      {
        role: h["role"].to_sym,
        content: h["content"]
      }
    end

    def extract_content(response)
      content = response.content
      return content if content.is_a?(String)
      return JSON.generate(content) if content.is_a?(Hash)

      content.to_s
    end

    def normalize_categorization_hash(content)
      hash =
        if content.is_a?(Hash)
          content.transform_keys(&:to_s)
        else
          parse_json(extract_json_object(content.to_s))
        end
      hash["suggested_new_category"] = nil if hash["suggested_new_category"].to_s.strip.empty?
      hash["rationale_short"] = nil if hash["rationale_short"].to_s.strip.empty?
      hash
    end

    def categorization_schema_fast
      {
        type: "object",
        properties: {
          category: { type: "string" },
          confidence: { type: "number" }
        },
        required: %w[category confidence],
        additionalProperties: false
      }
    end

    def categorization_schema_full
      {
        type: "object",
        properties: {
          category: { type: "string" },
          confidence: { type: "number" },
          rationale_short: { type: %w[string null] },
          suggested_new_category: { type: %w[string null] }
        },
        required: %w[category confidence rationale_short suggested_new_category],
        additionalProperties: false
      }
    end

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
  end
end
