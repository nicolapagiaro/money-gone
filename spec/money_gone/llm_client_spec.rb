# frozen_string_literal: true

require "spec_helper"

RSpec.describe MoneyGone::LlmClient do
  it "parses strict JSON response for categorization" do
    client = described_class.new(base_url: "http://localhost:1234/v1", model: "qwen3.2 8b")
    payload = '{"category":"Spesa","confidence":0.91,"rationale_short":"market","suggested_new_category":null}'
    expect(client.parse_json(payload)["category"]).to eq("Spesa")
  end
end
