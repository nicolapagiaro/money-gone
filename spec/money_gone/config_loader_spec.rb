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

    it "loads categories including Spesa and Altro" do
      config = loader.load_all
      expect(config[:categories]).to include("Spesa", "Altro")
    end

    it "loads rules with transfer key" do
      config = loader.load_all
      expect(config[:rules]).to have_key("transfer")
    end

    it "loads lmstudio model" do
      config = loader.load_all
      expect(config[:lmstudio]["model"]).to eq("qwen3.2 8b")
    end
  end
end
