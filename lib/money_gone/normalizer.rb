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
      text = value.to_s.strip
      decimal_text =
        if text.include?(",")
          text.delete(".").tr(",", ".")
        else
          text
        end

      Float(decimal_text)
    end

    def normalize_description(value)
      value.to_s.strip.gsub(/\s+/, " ").downcase
    end
  end
end
