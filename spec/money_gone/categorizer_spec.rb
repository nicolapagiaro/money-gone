# frozen_string_literal: true

require "spec_helper"

RSpec.describe MoneyGone::Categorizer do
  it "does not call llm when row is pre-categorized and marked to skip" do
    tx = {
      description_clean: "esselunga",
      category: "Supermercato e alimentari",
      category_source: "rule_includes",
      category_confidence: 1.0,
      skip_llm_categorization: true
    }
    fake_llm = instance_double("llm")
    expect(fake_llm).not_to receive(:categorize)

    out = described_class.new(
      categories: ["Supermercato e alimentari", "Altro"],
      llm_client: fake_llm
    ).categorize([tx]).first

    expect(out[:category]).to eq("Supermercato e alimentari")
    expect(out[:category_source]).to eq("rule_includes")
  end

  it "assigns Altro when llm category is not allowed" do
    tx = { description_clean: "misterioso addebito" }
    fake_llm = instance_double("llm")
    allow(fake_llm).to receive(:categorize).and_return(
      { "category" => "Crypto", "confidence" => 0.9, "suggested_new_category" => "Crypto" }
    )
    out = described_class.new(
      categories: %w[Spesa Altro],
      llm_client: fake_llm,
      confidence_threshold: 0.65,
      include_suggestions: true
    ).categorize([tx]).first
    expect(out[:category]).to eq("Altro")
    expect(out[:suggested_new_category]).to eq("Crypto")
  end

  it "matches category labels case-insensitively" do
    tx = { description_clean: "conad" }
    fake_llm = instance_double("llm")
    allow(fake_llm).to receive(:categorize).and_return(
      { "category" => "SUPERMERCATO E ALIMENTARI", "confidence" => 0.9, "suggested_new_category" => nil }
    )
    out = described_class.new(
      categories: ["Supermercato e alimentari", "Altro"],
      llm_client: fake_llm,
      confidence_threshold: 0.5
    ).categorize([tx]).first
    expect(out[:category]).to eq("Supermercato e alimentari")
  end

  it "matches labels when LM drops accents (e.g. caffe vs caffè)" do
    tx = { description_clean: "bar" }
    fake_llm = instance_double("llm")
    allow(fake_llm).to receive(:categorize).and_return(
      { "category" => "Bar e caffe", "confidence" => 0.88, "suggested_new_category" => nil }
    )
    out = described_class.new(
      categories: ["Bar e caffè", "Altro"],
      llm_client: fake_llm,
      confidence_threshold: 0.5
    ).categorize([tx]).first
    expect(out[:category]).to eq("Bar e caffè")
  end
end
