# frozen_string_literal: true

module MoneyGone
  class SchemaMapper
    class MappingError < StandardError; end

    HEADER_MAP = {
      /\A\s*(data|date|booking\s*date)(\s+(operazione|contabile|registrazione))?\s*\z/i => :booking_date,
      /\A\s*(importo|amount)(\s+(eur|euro))?\s*\z/i => :amount_raw,
      /\A\s*(descrizione|description|causale)\s*\z/i => :description_raw
    }.freeze

    def map_row(row)
      row.each_with_object({}) do |(header, value), mapped|
        canonical_key = canonical_key_for(header)
        mapped[canonical_key] = value if canonical_key
      end
    end

    private

    def canonical_key_for(header)
      HEADER_MAP.find { |pattern, _key| pattern.match?(header.to_s) }&.last
    end
  end
end
