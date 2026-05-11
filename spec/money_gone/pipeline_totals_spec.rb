# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe "Pipeline totals" do
  it "sums multiple rows into separate category buckets (no last-row overwrite)" do
    fake_llm = instance_double(MoneyGone::LlmClient)
    allow(fake_llm).to receive(:categorize) do |tx|
      if tx[:description_clean].to_s.include?("bar")
        { "category" => "Bar e caffe", "confidence" => 0.92, "suggested_new_category" => nil }
      else
        { "category" => "Altro", "confidence" => 0.9, "suggested_new_category" => nil }
      end
    end

    tempfile = Tempfile.new(["stmt", ".csv"])
    tempfile.write <<~CSV
      Data,Importo EUR,Descrizione
      2026-01-15,"-3,50",Pagamento bar
      2026-01-16,"-12,00",Spesa generica
    CSV
    tempfile.flush

    root = File.expand_path("../..", __dir__)
    result = Dir.chdir(root) do
      MoneyGone::Pipeline.run(
        [{ bank_id: "t", path: tempfile.path }],
        root: root,
        llm: fake_llm
      )
    end

    expect(result[:totals]["Bar e caffè"]).to be_within(0.01).of(-3.5)
    expect(result[:totals]["Altro"]).to be_within(0.01).of(-12.0)
    expect(result[:rows].size).to eq(2)
  ensure
    tempfile&.close!
  end
end
