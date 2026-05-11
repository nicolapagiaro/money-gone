# frozen_string_literal: true

require "spec_helper"

RSpec.describe MoneyGone::LlmClient do
  let(:client) { described_class.new(base_url: "http://localhost:1234/v1", model: "qwen3.2 8b") }

  it "parses strict JSON response for categorization" do
    payload = '{"category":"Spesa","confidence":0.91,"rationale_short":"market","suggested_new_category":null}'
    expect(client.parse_json(payload)["category"]).to eq("Spesa")
  end

  it "classifies a transaction via JSON from chat" do
    tx = {
      id: "x:1",
      bank_id: "x",
      booking_date: "2026-05-01",
      amount_signed: -12.5,
      description_clean: "supermercato"
    }
    allow(client).to receive(:chat).and_return(
      '{"category":"Spesa","confidence":0.88,"rationale_short":"spesa alimentare","suggested_new_category":null}'
    )
    out = client.categorize(tx, allowed_categories: %w[Spesa Altro], include_suggestions: true)
    expect(out["category"]).to eq("Spesa")
    expect(out["confidence"]).to be_within(0.01).of(0.88)
  end

  it "uses the compact prompt without max_tokens set on chat" do
    tx = {
      id: "x:1",
      bank_id: "x",
      booking_date: "2026-05-01",
      amount_signed: -12.5,
      description_clean: "tariffa atm"
    }
    expect(client).to receive(:chat).with(anything, hash_including(temperature: 0.2)).and_return('{"category":"Altro","confidence":0.6}')
    out = client.categorize(tx, allowed_categories: %w[Spesa Altro], include_suggestions: false)
    expect(out["category"]).to eq("Altro")
  end

  it "parses statement extraction JSON into canonical rows" do
    payload = <<~JSON.strip
      {"transactions":[{"booking_date":"2026-05-02","amount_raw":"-3,25","description_raw":"TABACCHI"}]}
    JSON
    allow(client).to receive(:chat).and_return(payload)
    rows = client.parse_statement_transactions("dummy text")
    expect(rows.size).to eq(1)
    expect(rows.first[:booking_date]).to eq("2026-05-02")
    expect(rows.first[:amount_raw]).to eq("-3,25")
    expect(rows.first[:description_raw]).to eq("TABACCHI")
  end
end
