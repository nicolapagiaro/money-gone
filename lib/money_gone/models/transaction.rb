# frozen_string_literal: true

module MoneyGone
  module Models
    Transaction = Struct.new(
      :id,
      :bank_id,
      :booking_date,
      :amount_signed,
      :description_raw,
      :description_clean,
      :raw,
      keyword_init: true
    )
  end
end
