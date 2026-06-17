# frozen_string_literal: true

module MoneyGone
  class Normalizer
    def normalize(transaction)
      transaction.merge(
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
  end
end
