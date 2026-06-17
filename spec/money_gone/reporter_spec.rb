# frozen_string_literal: true

require "spec_helper"

RSpec.describe MoneyGone::Reporter do
  it "prints source bank, destination bank, and amount for each transfer" do
    result = {
      flow_totals: { entrate: 0.0, uscite: -10.0, netto: -10.0 },
      totals: { "Altro" => -10.0 },
      transfers: [
        {
          id: "t1",
          amount_signed: -200.0,
          transfer_source_bank: "illimity",
          transfer_destination_bank: "conto_deposito"
        }
      ],
      suggestions: {},
      rows: []
    }

    output = capture_stdout { described_class.new.render(result) }

    expect(output).to include("Giroconti riconosciuti")
    expect(output).to include("t1 | illimity -> conto_deposito | -200.00")
  end

  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
