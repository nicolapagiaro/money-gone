# frozen_string_literal: true

require "spec_helper"

RSpec.describe MoneyGone::TransferDetector do
  it "marks high-score opposite transactions as transfers" do
    txs = [
      { id: "a1", bank_id: "a", booking_date: "2026-05-01", amount_signed: -100.0, description_clean: "bonifico" },
      { id: "b1", bank_id: "b", booking_date: "2026-05-01", amount_signed: 100.0, description_clean: "bonifico" }
    ]
    out = described_class.new.detect(txs)
    expect(out.find { |t| t[:id] == "a1" }[:excluded_from_spending]).to be(true)
  end
end
