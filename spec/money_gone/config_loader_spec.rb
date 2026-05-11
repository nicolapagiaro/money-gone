# frozen_string_literal: true

require "spec_helper"
require_relative "../../lib/money_gone/config_loader"

RSpec.describe MoneyGone::ConfigLoader do
  let(:root) { File.expand_path("../..", __dir__) }
  let(:loader) { described_class.new(root:) }

  describe "#load_all" do
    it "returns categories, rules, and lmstudio keys" do
      config = loader.load_all
      expect(config.keys).to contain_exactly(:categories, :rules, :lmstudio)
    end

    it "loads categories including Utenze, Altro and Supermercato" do
      config = loader.load_all
      expect(config[:categories]).to include("Altro", "Utenze", "Supermercato e alimentari")
    end

    it "loads rules with transfer key" do
      config = loader.load_all
      expect(config[:rules]).to have_key("transfer")
    end

    it "loads statement_pdf chunk defaults for PDF→LM extraction" do
      config = loader.load_all
      expect(config[:rules].dig("statement_pdf", "max_chunk_bytes")).to eq(3000)
    end

    it "loads lmstudio model and endpoint" do
      config = loader.load_all
      expect(config[:lmstudio]["model"]).to eq("qwen3.2 8b")
      expect(config[:lmstudio]["base_url"]).to include("127.0.0.1")
    end
  end
end
