# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MoneyGone::Infrastructure::ConsoleReport do
  it 'prints source bank, destination bank, and amount for each transfer' do
    result = {
      flow_totals: { entrate: 0.0, uscite: -10.0, netto: -10.0 },
      totals: { 'Altro' => -10.0 },
      transfers: [
        {
          id: 't1',
          amount_signed: -200.0,
          transfer_source_bank: 'illimity',
          transfer_destination_bank: 'conto_deposito'
        }
      ],
      suggestions: {},
      rows: []
    }

    output = StringIO.new
    described_class.new(io: output).render(result)

    text = output.string
    expect(text).to include('Giroconti riconosciuti')
    expect(text).to include('t1 | illimity -> conto_deposito | -200.00')
  end

  it 'prints top 3 expenses under each category total with indented sub-list' do
    result = {
      flow_totals: { entrate: 0.0, uscite: -100.0, netto: -100.0 },
      totals: { 'Spesa' => -100.0 },
      transfers: [],
      suggestions: {},
      rows: [
        { booking_date: Date.new(2026, 1, 10), category: 'Spesa', amount_signed: -50.0, description_clean: 'Affitto' },
        { booking_date: Date.new(2026, 1, 11), category: 'Spesa', amount_signed: -30.0,
          description_clean: 'Supermercato' },
        { booking_date: Date.new(2026, 1, 12), category: 'Spesa', amount_signed: -15.0,
          description_clean: 'Ristorante' },
        { booking_date: Date.new(2026, 1, 13), category: 'Spesa', amount_signed: -5.0, description_clean: 'Caffe' }
      ]
    }

    output = StringIO.new
    described_class.new(io: output).render(result)

    text = output.string
    expect(text).to include('- Spesa: -100.00')
    expect(text).to include('    2026-01-10 | Affitto | -50.00')
    expect(text).to include('    2026-01-11 | Supermercato | -30.00')
    expect(text).to include('    2026-01-12 | Ristorante | -15.00')
    expect(text).not_to include('2026-01-13 | Caffe | -5.00')
  end
end
