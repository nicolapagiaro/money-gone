# frozen_string_literal: true

module MoneyGone
  class SchemaMapper
    class MappingError < StandardError; end

    # Ordine: dal più specifico al più generico (prima corrispondenza vince).
    HEADER_MAP = {
      # Data / valuta movimento
      /\A\s*(data|date|booking\s*date)(\s+(operazione|contabile|registrazione|valuta|transazione|movimento))?\s*\z/i => :booking_date,
      /\A\s*data\s*\z/i => :booking_date,

      # Importo / movimento in denaro
      /\A\s*denaro\s+in\s+entrata\s*\/\s*uscita\s*\z/i => :amount_raw,
      /\A\s*denaro\s+entrata\s*\/\s*uscita\s*\z/i => :amount_raw,
      /\A\s*entrata\s*\/\s*uscita\s*\z/i => :amount_raw,
      /\A\s*(importo|amount)(?:\s*\([^)]*\))?(?:\s+(eur|euro|£|\$|chf))?\s*\z/i => :amount_raw,
      /\A\s*(importo|amount)\s*\z/i => :amount_raw,
      /\A\s*(movimento|operazione)\s+(dare|avere)\s*\z/i => :amount_raw,
      /\A\s*(dare|avere)\s*\z/i => :amount_raw,
      /\A\s*(valore|ammontare)(?:\s+(eur|euro))?\s*\z/i => :amount_raw,

      # Descrizione / causale
      /\A\s*(descrizione|description|descrizione\s+motivo|oggetto|causale|note)\s*\z/i => :description_raw
    }.freeze

    # Excel spesso inserisce BOM, NBSP o spazi "strani" negli header: senza normalizzazione i regex \A...\z non matchano mai.
    def self.normalize_header_label(header)
      s = header.to_s.dup
      s.force_encoding(Encoding::UTF_8)
      s = s.sub(/\A\uFEFF/, "")
      s = s.gsub(/[\u200B\u200C\u200D\uFEFF]/, "")
      s.tr!("\u00A0\u202F", " ") # NBSP, narrow NBSP
      s.gsub!(/[[:space:]]+/, " ")
      s.strip
    end

    def map_row(row)
      row.each_with_object({}) do |(header, value), mapped|
        canonical_key = canonical_key_for(header)
        mapped[canonical_key] = value if canonical_key
      end
    end

    private

    def canonical_key_for(header)
      h = self.class.normalize_header_label(header)
      HEADER_MAP.find { |pattern, _key| pattern.match?(h) }&.last
    end
  end
end
