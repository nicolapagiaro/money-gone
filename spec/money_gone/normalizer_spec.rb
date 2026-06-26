# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/money_gone/normalizer'

RSpec.describe MoneyGone::Normalizer do
  describe '#normalize' do
    it 'normalizes comma-decimal amount and clean description' do
      tx = { amount_raw: '-12,50', description_raw: '  SUPER   MERCATO ' }

      normalized = described_class.new.normalize(tx)

      expect(normalized[:amount_signed]).to eq(-12.5)
      expect(normalized[:description_clean]).to eq('super mercato')
    end

    it 'normalizes amount even when trailing euro symbol is misencoded' do
      tx = { amount_raw: "33,31â\u0082¬", description_raw: 'Bonifico' }

      normalized = described_class.new.normalize(tx)

      expect(normalized[:amount_signed]).to eq(33.31)
    end

    it 'parses booking_date in dd-mm-yyyy format' do
      tx = { booking_date: '10-05-2026', amount_raw: '1,00', description_raw: 'Bonifico' }

      normalized = described_class.new.normalize(tx)

      expect(normalized[:booking_date]).to eq(Date.new(2026, 5, 10))
    end

    it 'parses booking_date in italian short month format' do
      tx = { booking_date: '10 mag 2026', amount_raw: '1,00', description_raw: 'Bonifico' }

      normalized = described_class.new.normalize(tx)

      expect(normalized[:booking_date]).to eq(Date.new(2026, 5, 10))
    end
  end
end
