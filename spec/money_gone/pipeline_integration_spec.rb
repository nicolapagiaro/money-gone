# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'analyze integration' do
  it 'prints category totals and transfer section' do
    root = File.expand_path('../..', __dir__)
    out = `cd #{root} && ruby bin/money-gone analyze --stub a:spec/fixtures/bank_a.csv b:spec/fixtures/bank_b.xlsx`
    expect(out).to include('Riepilogo flussi')
    expect(out).to include('Totale entrate')
    expect(out).to include('Totale uscite')
    expect(out).to include('Flusso di cassa netto')
    expect(out).to include('Totali per categoria')
    expect(out).to include('Giroconti riconosciuti')
    expect(out).to include('Nuove categorie suggerite')
  end
end
