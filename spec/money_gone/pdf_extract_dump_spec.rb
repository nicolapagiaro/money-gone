# frozen_string_literal: true

require "spec_helper"

RSpec.describe MoneyGone::PdfExtractDump do
  it "writes UTF-8 text under tmp/money-gone-pdf-extract" do
    Dir.mktmpdir do |root|
      path = described_class.write!(
        root: root,
        bank_id: "bank-a",
        source_path: "/somewhere/estratto conto.pdf",
        text: "riga uno\nriga due"
      )

      expect(path).to include("money-gone-pdf-extract")
      expect(File.file?(path)).to be true
      expect(File.read(path, encoding: Encoding::UTF_8)).to eq("riga uno\nriga due")
    end
  end
end
