# frozen_string_literal: true

require "spec_helper"
require_relative "../../lib/money_gone/schema_mapper"

RSpec.describe MoneyGone::SchemaMapper do
  describe "#map_row" do
    it "maps italian-like source headers to canonical keys" do
      row = {
        "Data operazione" => "2026-05-01",
        "Importo EUR" => "-12,50",
        "Descrizione" => "Supermercato"
      }

      mapped = described_class.new.map_row(row)

      expect(mapped).to include(:booking_date, :amount_raw, :description_raw)
    end
  end
end
