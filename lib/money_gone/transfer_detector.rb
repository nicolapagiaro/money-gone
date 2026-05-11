# frozen_string_literal: true

module MoneyGone
  class TransferDetector
    def detect(transactions)
      pairs = transactions.combination(2).select do |a, b|
        a[:bank_id] != b[:bank_id] && (a[:amount_signed] + b[:amount_signed]).abs < 0.01
      end
      pairs.each_with_index do |(a, b), idx|
        gid = "tg#{idx + 1}"
        a[:excluded_from_spending] = true
        b[:excluded_from_spending] = true
        a[:excluded_reason] = b[:excluded_reason] = "internal_transfer"
        a[:transfer_group_id] = b[:transfer_group_id] = gid
      end
      transactions
    end
  end
end
