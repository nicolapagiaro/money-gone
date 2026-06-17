# frozen_string_literal: true

require "date"

module MoneyGone
  class Normalizer
    ITALIAN_MONTHS = {
      "gen" => 1,
      "feb" => 2,
      "mar" => 3,
      "apr" => 4,
      "mag" => 5,
      "giu" => 6,
      "lug" => 7,
      "ago" => 8,
      "set" => 9,
      "sett" => 9,
      "ott" => 10,
      "nov" => 11,
      "dic" => 12
    }.freeze

    def normalize(transaction)
      transaction.merge(
        booking_date: normalize_booking_date(transaction[:booking_date]),
        amount_signed: normalize_amount(transaction[:amount_raw]),
        description_clean: normalize_description(transaction[:description_raw])
      )
    end

    private

    def normalize_amount(value)
      text = sanitize_amount_text(value)
      decimal_text =
        if text.include?(",")
          text.delete(".").tr(",", ".")
        else
          text
        end

      Float(decimal_text)
    end

    def sanitize_amount_text(value)
      text = value.to_s.dup
      text.force_encoding(Encoding::UTF_8)
      text = text.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "")
      text.tr!("\u00A0\u202F", " ")
      text.gsub!(/[[:space:]]+/, "")
      text.gsub!(/[^\d,.\-+]/, "")
      text
    end

    def normalize_description(value)
      value.to_s.strip.gsub(/\s+/, " ").downcase
    end

    def normalize_booking_date(value)
      return value if value.is_a?(Date)

      text = value.to_s.strip.downcase
      return value if text.empty?

      dd_mm_yyyy = text.match(/\A(\d{1,2})-(\d{1,2})-(\d{4})\z/)
      if dd_mm_yyyy
        day, month, year = dd_mm_yyyy.captures.map(&:to_i)
        return Date.new(year, month, day)
      end

      ita_month = text.match(/\A(\d{1,2})\s+([[:alpha:]\.]+)\s+(\d{4})\z/)
      if ita_month
        day = ita_month[1].to_i
        month_label = ita_month[2].delete(".")
        year = ita_month[3].to_i
        month = ITALIAN_MONTHS[month_label]
        return Date.new(year, month, day) if month
      end

      Date.parse(text)
    rescue Date::Error
      value
    end
  end
end
