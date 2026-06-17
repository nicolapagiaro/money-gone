# frozen_string_literal: true

require "spec_helper"

RSpec.describe MoneyGone::TransferDetector do
  it "marks transactions as transfers when raw description matches configured keyword" do
    txs = [
      {
        id: "a1",
        bank_id: "a",
        booking_date: "2026-05-01",
        amount_signed: -100.0,
        description_raw: "Versamento su conto deposito",
        description_clean: "versamento su conto deposito"
      },
      {
        id: "b1",
        bank_id: "b",
        booking_date: "2026-05-12",
        amount_signed: 45.0,
        description_raw: "Pagamento supermercato",
        description_clean: "pagamento supermercato"
      }
    ]

    out = described_class.new.detect(
      txs,
      rules: {
        "description_raw_keywords" => ["conto deposito"]
      }
    )

    a = out.find { |t| t[:id] == "a1" }
    b = out.find { |t| t[:id] == "b1" }
    expect(a[:excluded_from_spending]).to be(true)
    expect(a[:excluded_reason]).to eq("internal_transfer_by_description")
    expect(a[:transfer_source_bank]).to eq("a")
    expect(a[:transfer_destination_bank]).to eq("conto_deposito")
    expect(b[:excluded_from_spending]).not_to be(true)
  end

  it "supports exact raw description rules" do
    txs = [
      {
        id: "r1",
        bank_id: "a",
        booking_date: "2026-05-10",
        amount_signed: -99.0,
        description_raw: "GIROCONTO INTERNO DEPOSITO",
        description_clean: "giroconto interno deposito"
      },
      {
        id: "r2",
        bank_id: "a",
        booking_date: "2026-05-11",
        amount_signed: 99.0,
        description_raw: "Giroconto interno deposito",
        description_clean: "accredito interno"
      }
    ]

    out = described_class.new.detect(
      txs,
      rules: {
        "description_raw_exact" => ["giroconto interno deposito"]
      }
    )

    a = out.find { |t| t[:id] == "r1" }
    b = out.find { |t| t[:id] == "r2" }
    expect(a[:excluded_from_spending]).to be(true)
    expect(b[:excluded_from_spending]).to be(true)
    expect(a[:transfer_source_bank]).to eq("a")
    expect(a[:transfer_destination_bank]).to eq("a")
  end

  it "does not use amount or date matching when descriptions do not match rules" do
    txs = [
      {
        id: "n1",
        bank_id: "a",
        booking_date: "2026-05-01",
        amount_signed: -1000.0,
        description_raw: "Stipendio ricevuto",
        description_clean: "stipendio ricevuto"
      },
      {
        id: "n2",
        bank_id: "a",
        booking_date: "2026-05-10",
        amount_signed: 1000.0,
        description_raw: "Pagamento affitto",
        description_clean: "pagamento affitto"
      }
    ]

    out = described_class.new.detect(
      txs,
      rules: {
        "description_raw_keywords" => ["conto deposito"]
      }
    )

    a = out.find { |t| t[:id] == "n1" }
    b = out.find { |t| t[:id] == "n2" }
    expect(a[:excluded_from_spending]).not_to be(true)
    expect(b[:excluded_from_spending]).not_to be(true)
  end
end
