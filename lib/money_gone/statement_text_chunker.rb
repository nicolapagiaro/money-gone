# frozen_string_literal: true

module MoneyGone
  # Suddivide il testo estratto da PDF (marcato con "--- Pagina N ---") in blocchi che rispettano max_chars (UTF-8 bytes).
  class StatementTextChunker
    # Conservativo per modelli con contesto ~4096 token (prompt sistema + istruzioni + testo utente).
    DEFAULT_MAX_CHARS = 3000

    MIN_BYTES = 768
    MAX_BYTES_CAP = 120_000

    PAGE_SPLIT = /\n(?=--- Pagina \d+ ---)/

    # Precedenza: MONEY_GONE_STATEMENT_CHUNK_BYTES, poi valore da config/rules.yml, poi default.
    def self.effective_max_bytes(config_value = nil)
      env = ENV["MONEY_GONE_STATEMENT_CHUNK_BYTES"].to_s.strip
      v = if !env.empty?
            env.to_i
          elsif config_value.to_i.positive?
            config_value.to_i
          else
            DEFAULT_MAX_CHARS
          end
      v = MIN_BYTES if v < MIN_BYTES
      v = MAX_BYTES_CAP if v > MAX_BYTES_CAP
      v
    end

    def self.chunk(text, max_chars: DEFAULT_MAX_CHARS)
      text = text.to_s
      return [text] if text.bytesize <= max_chars

      pages = text.split(PAGE_SPLIT).map(&:strip).reject(&:empty?)
      pages = [text.strip] if pages.empty?

      chunks = []
      buffer = +""
      pages.each do |page|
        sep = buffer.empty? ? "" : "\n\n"
        candidate = "#{buffer}#{sep}#{page}"

        if candidate.bytesize <= max_chars
          buffer = +candidate
          next
        end

        chunks << buffer.strip unless buffer.empty?
        buffer = +""

        if page.bytesize <= max_chars
          buffer = +page
        else
          chunks.concat(split_hard(page, max_chars))
        end
      end

      chunks << buffer.strip unless buffer.empty?
      chunks.reject!(&:empty?)
      chunks = split_hard(text, max_chars) if chunks.empty?
      chunks
    end

    def self.split_hard(text, max_chars)
      out = []
      current = +""
      text.each_char do |ch|
        if !current.empty? && (current.bytesize + ch.bytesize) > max_chars
          out << current
          current = +""
        end
        current << ch
      end
      out << current unless current.empty?
      out
    end
  end
end
