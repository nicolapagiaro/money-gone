# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'

RSpec.describe MoneyGone::Importer do
  it 'builds normalized transactions from a CSV with Italian-style headers' do
    tempfile = Tempfile.new(['statement', '.csv'])
    tempfile.write <<~CSV
      Data operazione,Importo EUR,Descrizione
      "2026-05-01","-12,50","  SUPER   MERCATO "
    CSV
    tempfile.flush

    rows = described_class.new.import_csv(tempfile.path, bank_id: 'a')
    expect(rows.size).to eq(1)

    tx = rows.first
    expect(tx.id).to eq('a:1')
    expect(tx.bank_id).to eq('a')
    expect(tx.booking_date).to eq(Date.new(2026, 5, 1))
    expect(tx.amount_signed).to eq(-12.5)
    expect(tx.description_raw.to_s.strip).to eq('SUPER   MERCATO')
    expect(tx.description_clean).to eq('super mercato')
    expect(tx.raw['Data operazione']).to eq('2026-05-01')
    expect(tx.raw['Importo EUR']).to eq('-12,50')
  ensure
    tempfile&.close!
  end
end
