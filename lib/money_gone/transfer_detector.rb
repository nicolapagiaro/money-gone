# frozen_string_literal: true

module MoneyGone
  class TransferDetector
    DEFAULT_RULES = {
      "enabled" => true,
      "description_raw_keywords" => [],
      "description_raw_exact" => []
    }.freeze

    def detect(transactions, rules: {})
      cfg = DEFAULT_RULES.merge(stringify_keys(rules))
      return transactions unless cfg["enabled"]

      keywords = normalize_rules(cfg["description_raw_keywords"])
      exact_rules = normalize_rules(cfg["description_raw_exact"])
      gid_idx = 1

      transactions.each do |tx|
        next unless transfer_by_description?(tx, keywords: keywords, exact_rules: exact_rules)

        tx[:excluded_from_spending] = true
        tx[:excluded_reason] = "internal_transfer_by_description"
        tx[:transfer_group_id] = "tg#{gid_idx}"
        source_bank, destination_bank = infer_transfer_direction(tx)
        tx[:transfer_source_bank] = source_bank
        tx[:transfer_destination_bank] = destination_bank
        gid_idx += 1
      end

      transactions
    end

    private

    def transfer_by_description?(tx, keywords:, exact_rules:)
      raw = tx[:description_raw].to_s.downcase.strip
      return false if raw.empty?
      return true if exact_rules.include?(raw)

      keywords.any? { |rule| raw.include?(rule) }
    end

    def normalize_rules(values)
      Array(values).map { |v| v.to_s.downcase.strip }.reject(&:empty?)
    end

    def infer_transfer_direction(tx)
      bank = tx[:bank_id].to_s
      raw = tx[:description_raw].to_s.downcase

      if raw.include?("versamento su")
        [bank, "conto_deposito"]
      elsif raw.include?("versamento da")
        ["conto_deposito", bank]
      else
        [bank, bank]
      end
    end

    def stringify_keys(hash)
      hash.each_with_object({}) { |(k, v), acc| acc[k.to_s] = v }
    end
  end
end
