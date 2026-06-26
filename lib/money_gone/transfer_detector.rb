# frozen_string_literal: true

module MoneyGone
  class TransferDetector
    class CrossBankMatcher
      def pair?(left, right, tolerance:)
        return false unless distinct_active_banks?(left, right)
        return false unless same_booking_date?(left, right)

        opposite_amounts?(left, right, tolerance:)
      end

      def direction(left, right)
        banks = debit_and_credit_banks(left, right)
        banks || [left[:bank_id].to_s, right[:bank_id].to_s]
      end

      private

      def distinct_active_banks?(left, right)
        !left[:excluded_from_spending] &&
          !right[:excluded_from_spending] &&
          left[:bank_id].to_s != right[:bank_id].to_s
      end

      def same_booking_date?(left, right)
        left[:booking_date].to_s == right[:booking_date].to_s
      end

      def opposite_amounts?(left, right, tolerance:)
        (left[:amount_signed].to_f + right[:amount_signed].to_f).abs <= tolerance
      end

      def debit_and_credit_banks(left, right)
        return [left[:bank_id].to_s, right[:bank_id].to_s] if left_debit?(left, right)
        return [right[:bank_id].to_s, left[:bank_id].to_s] if left_debit?(right, left)

        nil
      end

      def left_debit?(debit_row, credit_row)
        debit_row[:amount_signed].to_f.negative? && credit_row[:amount_signed].to_f.positive?
      end
    end

    DEFAULT_RULES = {
      'enabled' => true,
      'description_raw_keywords' => [],
      'description_raw_exact' => [],
      'cross_bank_amount_tolerance' => 0.01
    }.freeze

    def detect(transactions, rules: {})
      cfg = DEFAULT_RULES.merge(stringify_keys(rules))
      return transactions unless cfg['enabled']

      keywords = normalize_rules(cfg['description_raw_keywords'])
      exact_rules = normalize_rules(cfg['description_raw_exact'])
      tolerance = cfg['cross_bank_amount_tolerance'].to_f
      gid_idx = mark_description_transfers(transactions, keywords:, exact_rules:)
      mark_cross_bank_amount_date_transfers(transactions, tolerance:, gid_idx:)

      transactions
    end

    private

    def mark_description_transfers(transactions, keywords:, exact_rules:)
      gid_idx = 1
      transactions.each do |row|
        next unless transfer_by_description?(row, keywords:, exact_rules:)

        apply_description_transfer!(row, gid_idx)
        gid_idx += 1
      end
      gid_idx
    end

    def apply_description_transfer!(row, gid_idx)
      row[:excluded_from_spending] = true
      row[:excluded_reason] = 'internal_transfer_by_description'
      row[:transfer_group_id] = "tg#{gid_idx}"
      source_bank, destination_bank = infer_transfer_direction(row)
      row[:transfer_source_bank] = source_bank
      row[:transfer_destination_bank] = destination_bank
    end

    def transfer_by_description?(row, keywords:, exact_rules:)
      raw = row[:description_raw].to_s.downcase.strip
      return false if raw.empty?
      return true if exact_rules.include?(raw)

      keywords.any? { |rule| raw.include?(rule) }
    end

    def normalize_rules(values)
      Array(values).map { |value| value.to_s.downcase.strip }.reject(&:empty?)
    end

    def infer_transfer_direction(row)
      bank = row[:bank_id].to_s
      raw = row[:description_raw].to_s.downcase

      if raw.include?('versamento su')
        [bank, 'conto_deposito']
      elsif raw.include?('versamento da')
        ['conto_deposito', bank]
      else
        [bank, bank]
      end
    end

    def mark_cross_bank_amount_date_transfers(transactions, tolerance:, gid_idx:)
      matcher = CrossBankMatcher.new
      unmarked = transactions.reject { |row| row[:excluded_from_spending] }
      unmarked.combination(2) do |left, right|
        next unless matcher.pair?(left, right, tolerance:)

        source, destination = matcher.direction(left, right)
        apply_cross_bank_pair!(left, right, source, destination, gid_idx)
        gid_idx += 1
      end
    end

    def apply_cross_bank_pair!(left, right, source, destination, gid_idx)
      group_id = "tg#{gid_idx}"
      [left, right].each do |row|
        row[:excluded_from_spending] = true
        row[:excluded_reason] = 'internal_transfer_cross_bank_amount_date'
        row[:transfer_group_id] = group_id
        row[:transfer_source_bank] = source
        row[:transfer_destination_bank] = destination
      end
    end

    def stringify_keys(hash)
      hash.each_with_object({}) { |(key, value), acc| acc[key.to_s] = value }
    end
  end
end
