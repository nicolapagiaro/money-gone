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
        banks || [left.bank_id.to_s, right.bank_id.to_s]
      end

      private

      def distinct_active_banks?(left, right)
        !left.transfer? &&
          !right.transfer? &&
          left.bank_id.to_s != right.bank_id.to_s
      end

      def same_booking_date?(left, right)
        left.booking_date.to_s == right.booking_date.to_s
      end

      def opposite_amounts?(left, right, tolerance:)
        (left.amount_signed.to_f + right.amount_signed.to_f).abs <= tolerance
      end

      def debit_and_credit_banks(left, right)
        return [left.bank_id.to_s, right.bank_id.to_s] if left_debit?(left, right)
        return [right.bank_id.to_s, left.bank_id.to_s] if left_debit?(right, left)

        nil
      end

      def left_debit?(debit_row, credit_row)
        debit_row.amount_signed.to_f.negative? && credit_row.amount_signed.to_f.positive?
      end
    end

    DEFAULT_RULES = {
      'enabled' => true,
      'description_raw_keywords' => [],
      'description_raw_exact' => [],
      'cross_bank_amount_tolerance' => 0.01
    }.freeze

    def detect(movements, rules: {})
      cfg = DEFAULT_RULES.merge(stringify_keys(rules))
      return movements unless cfg['enabled']

      keywords = normalize_rules(cfg['description_raw_keywords'])
      exact_rules = normalize_rules(cfg['description_raw_exact'])
      tolerance = cfg['cross_bank_amount_tolerance'].to_f
      gid_idx = mark_description_transfers(movements, keywords:, exact_rules:)
      mark_cross_bank_amount_date_transfers(movements, tolerance:, gid_idx:)

      movements
    end

    private

    def mark_description_transfers(movements, keywords:, exact_rules:)
      gid_idx = 1
      movements.each do |movement|
        next unless transfer_by_description?(movement, keywords:, exact_rules:)

        apply_description_transfer!(movement, gid_idx)
        gid_idx += 1
      end
      gid_idx
    end

    def apply_description_transfer!(movement, gid_idx)
      source_bank, destination_bank = infer_transfer_direction(movement)
      movement.exclude_as_transfer!(
        reason: 'internal_transfer_by_description',
        group_id: "tg#{gid_idx}",
        source_bank: source_bank,
        destination_bank: destination_bank
      )
    end

    def transfer_by_description?(movement, keywords:, exact_rules:)
      raw = movement.description_raw.to_s.downcase.strip
      return false if raw.empty?
      return true if exact_rules.include?(raw)

      keywords.any? { |rule| raw.include?(rule) }
    end

    def normalize_rules(values)
      Array(values).map { |value| value.to_s.downcase.strip }.reject(&:empty?)
    end

    def infer_transfer_direction(movement)
      bank = movement.bank_id.to_s
      raw = movement.description_raw.to_s.downcase

      if raw.include?('versamento su')
        [bank, 'conto_deposito']
      elsif raw.include?('versamento da')
        ['conto_deposito', bank]
      else
        [bank, bank]
      end
    end

    def mark_cross_bank_amount_date_transfers(movements, tolerance:, gid_idx:)
      matcher = CrossBankMatcher.new
      unmarked = movements.reject(&:transfer?)
      unmarked.combination(2) do |left, right|
        next unless matcher.pair?(left, right, tolerance:)

        source, destination = matcher.direction(left, right)
        apply_cross_bank_pair!(left, right, source, destination, gid_idx)
        gid_idx += 1
      end
    end

    def apply_cross_bank_pair!(left, right, source, destination, gid_idx)
      group_id = "tg#{gid_idx}"
      [left, right].each do |movement|
        movement.exclude_as_transfer!(
          reason: 'internal_transfer_cross_bank_amount_date',
          group_id: group_id,
          source_bank: source,
          destination_bank: destination
        )
      end
    end

    def stringify_keys(hash)
      hash.each_with_object({}) { |(key, value), acc| acc[key.to_s] = value }
    end
  end
end
