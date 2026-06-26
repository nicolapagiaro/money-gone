# frozen_string_literal: true

require 'spec_helper'
require_relative '../../lib/money_gone/schema_mapper'

RSpec.describe MoneyGone::SchemaMapper do
  describe '#map_row' do
    it 'maps italian-like source headers to canonical keys' do
      row = {
        'Data operazione' => '2026-05-01',
        'Importo EUR' => '-12,50',
        'Descrizione' => 'Supermercato'
      }

      mapped = described_class.new.map_row(row)

      expect(mapped).to include(:booking_date, :amount_raw, :description_raw)
    end

    it 'maps Microsoft / Excel style Denaro in entrata/uscita to amount' do
      row = {
        'Data' => '2026-01-15',
        'Descrizione' => 'Pagamento',
        'Denaro in entrata/uscita' => '-25,99'
      }

      mapped = described_class.new.map_row(row)

      expect(mapped[:amount_raw]).to eq('-25,99')
      expect(mapped[:booking_date]).to eq('2026-01-15')
      expect(mapped[:description_raw]).to eq('Pagamento')
    end

    it 'normalizes Excel BOM, NBSP and unicode spaces so headers still match' do
      row = {
        "\uFEFFData" => '2026-01-01',
        "Descrizione\u00A0" => 'Caffè',
        "Denaro\u00A0in\u00A0entrata/uscita" => '-3,50'
      }

      mapped = described_class.new.map_row(row)

      expect(mapped[:booking_date]).to eq('2026-01-01')
      expect(mapped[:description_raw]).to eq('Caffè')
      expect(mapped[:amount_raw]).to eq('-3,50')
    end

    it 'maps split entrate/uscite columns to signed amount_raw' do
      income_row = {
        'Data' => '2026-06-01',
        'Descrizione' => 'Stipendio',
        'Entrate' => '1500,00',
        'Uscite' => ''
      }
      expense_row = {
        'Data' => '2026-06-02',
        'Descrizione' => 'Affitto',
        'Entrate' => '',
        'Uscite' => '800,00'
      }

      income_mapped = described_class.new.map_row(income_row)
      expense_mapped = described_class.new.map_row(expense_row)

      expect(income_mapped[:amount_raw]).to eq('1500,00')
      expect(expense_mapped[:amount_raw]).to eq('-800,00')
    end
  end
end
