# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MoneyGone::Domain::CategoryCatalog do
  let(:labels) { ['Supermercato e alimentari', 'Bar e caffè', 'Altro'] }
  let(:catalog) { described_class.new(labels) }

  describe '#resolve' do
    it 'returns exact label match' do
      expect(catalog.resolve('Altro')).to eq('Altro')
    end

    it 'matches case-insensitively' do
      expect(catalog.resolve('SUPERMERCATO E ALIMENTARI')).to eq('Supermercato e alimentari')
    end

    it 'matches when accents differ' do
      expect(catalog.resolve('Bar e caffe')).to eq('Bar e caffè')
    end

    it 'returns nil for empty label' do
      expect(catalog.resolve('   ')).to be_nil
    end

    it 'returns nil for unknown label' do
      expect(catalog.resolve('Crypto')).to be_nil
    end
  end

  describe '#same_label?' do
    it 'compares folded labels' do
      expect(catalog.same_label?('Bar e caffè', 'BAR E CAFFE')).to be(true)
      expect(catalog.same_label?('Altro', 'Spesa')).to be(false)
    end
  end

  describe '#match_description_includes' do
    it 'resolves category when description contains needle' do
      rules = { 'esselunga' => 'Supermercato e alimentari' }
      expect(catalog.match_description_includes('Esselunga Milano', rules))
        .to eq('Supermercato e alimentari')
    end

    it 'returns nil when no rule matches' do
      rules = { 'esselunga' => 'Supermercato e alimentari' }
      expect(catalog.match_description_includes('spesa generica', rules)).to be_nil
    end

    it 'returns nil for empty rules' do
      expect(catalog.match_description_includes('esselunga', {})).to be_nil
    end
  end
end
