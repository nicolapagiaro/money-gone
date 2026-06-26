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
      %r{\A\s*denaro\s+in\s+entrata\s*/\s*uscita\s*\z}i => :amount_raw,
      %r{\A\s*denaro\s+entrata\s*/\s*uscita\s*\z}i => :amount_raw,
      %r{\A\s*entrata\s*/\s*uscita\s*\z}i => :amount_raw,
      /\A\s*entrate?\s*\z/i => :amount_in_raw,
      /\A\s*accrediti?\s*\z/i => :amount_in_raw,
      /\A\s*uscite?\s*\z/i => :amount_out_raw,
      /\A\s*addebiti?\s*\z/i => :amount_out_raw,
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
      text = header.to_s.dup
      text.force_encoding(Encoding::UTF_8)
      text = text.delete_prefix('﻿')
      text = text.gsub(/[\u200B\u200C\u200D\uFEFF]/, '')
      text.tr!("\u00A0\u202F", ' ') # NBSP, narrow NBSP
      text.gsub!(/[[:space:]]+/, ' ')
      text.strip
    end

    def map_row(row)
      mapped = row.each_with_object({}) do |(header, value), acc|
        canonical_key = canonical_key_for(header)
        acc[canonical_key] = value if canonical_key
      end

      fill_amount_from_split_columns!(mapped)
      mapped
    end

    private

    def fill_amount_from_split_columns!(mapped)
      mapped[:amount_raw] ||= resolve_amount_raw(mapped[:amount_in_raw], mapped[:amount_out_raw])
      mapped.delete(:amount_in_raw)
      mapped.delete(:amount_out_raw)
    end

    def resolve_amount_raw(amount_in, amount_out)
      return unsigned_amount_text(amount_in) if present?(amount_in)
      return signed_negative_amount_text(amount_out) if present?(amount_out)

      nil
    end

    def present?(value)
      !value.to_s.strip.empty?
    end

    def unsigned_amount_text(value)
      value.to_s.strip.delete_prefix('+').delete_prefix('-')
    end

    def signed_negative_amount_text(value)
      normalized = unsigned_amount_text(value)
      "-#{normalized}"
    end

    def canonical_key_for(header)
      label = self.class.normalize_header_label(header)
      HEADER_MAP.find { |pattern, _key| pattern.match?(label) }&.last
    end
  end
end
