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
      /\A\s*(importo|amount)(\s*\([^)]*\))?\s*(\s+(eur|euro|£|\$|chf))?\s*\z/i => :amount_raw,
      /\A\s*(importo|amount)(\s+(eur|euro|£|\$|chf))?\s*\z/i => :amount_raw,
      /\A\s*(movimento|operazione)\s+(dare|avere)\s*\z/i => :amount_raw,
      /\A\s*(dare|avere)\s*\z/i => :amount_raw,
      /\A\s*(valore|ammontare)\s*(\s+(eur|euro))?\s*\z/i => :amount_raw,

      # Descrizione / causale
      /\A\s*(descrizione|description|descrizione\s+motivo|oggetto|causale|note)\s*\z/i => :description_raw
    }.freeze

    def map_row(row)
      row.each_with_object({}) do |(header, value), mapped|
        canonical_key = canonical_key_for(header)
        mapped[canonical_key] = value if canonical_key
      end
    end

    private

    def canonical_key_for(header)
      h = header.to_s.strip
      HEADER_MAP.find { |pattern, _key| pattern.match?(h) }&.last
    end
  end
end
