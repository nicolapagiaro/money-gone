# frozen_string_literal: true

require "spec_helper"

RSpec.describe MoneyGone::Categorizer do
  it "assigns Altro when llm category is not allowed" do
    tx = { description_clean: "misterioso addebito" }
    fake_llm = instance_double("llm")
    allow(fake_llm).to receive(:categorize).and_return(
      { "category" => "Crypto", "confidence" => 0.9, "suggested_new_category" => "Crypto" }
    )
    out = described_class.new(categories: %w[Spesa Altro], llm_client: fake_llm).categorize([tx]).first
    expect(out[:category]).to eq("Altro")
    expect(out[:suggested_new_category]).to eq("Crypto")
  end
end
