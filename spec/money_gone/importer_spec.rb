# frozen_string_literal: true

require "spec_helper"
require "tempfile"

RSpec.describe MoneyGone::Importer do
  it "builds normalized transactions from a CSV with Italian-style headers" do
    tempfile = Tempfile.new(["statement", ".csv"])
    tempfile.write <<~CSV
      Data operazione,Importo EUR,Descrizione
      "2026-05-01","-12,50","  SUPER   MERCATO "
    CSV
    tempfile.flush

    rows = described_class.new.import_csv(tempfile.path, bank_id: "a")
    expect(rows.size).to eq(1)

    tx = rows.first
    expect(tx.id).to eq("a:1")
    expect(tx.bank_id).to eq("a")
    expect(tx.booking_date).to eq("2026-05-01")
    expect(tx.amount_signed).to eq(-12.5)
    expect(tx.description_raw.to_s.strip).to eq("SUPER   MERCATO")
    expect(tx.description_clean).to eq("super mercato")
    expect(tx.raw["Data operazione"]).to eq("2026-05-01")
    expect(tx.raw["Importo EUR"]).to eq("-12,50")
  ensure
    tempfile&.close!
  end

  it "imports PDF via extractor + LLM into normalized transactions" do
    llm = instance_double(MoneyGone::LlmClient)
    extractor = instance_double(MoneyGone::PdfStatementExtractor)
    allow(extractor).to receive(:extract).with("/tmp/x.pdf").and_return("--- Pagina 1 ---\nPOS TEST")
    allow(llm).to receive(:parse_statement_transactions).with("--- Pagina 1 ---\nPOS TEST").and_return(
      [{ booking_date: "2026-05-10", amount_raw: "-20,00", description_raw: "POS TEST" }]
    )

    rows = described_class.new(llm_client: llm, pdf_extractor: extractor, dump_pdf_extract: false).import_pdf("/tmp/x.pdf",
                                                                                                             bank_id: "pdfbank")
    expect(rows.size).to eq(1)
    tx = rows.first
    expect(tx.bank_id).to eq("pdfbank")
    expect(tx.booking_date).to eq("2026-05-10")
    expect(tx.amount_signed).to eq(-20.0)
    expect(tx.description_clean).to eq("pos test")
  end

  it "writes extracted PDF text under project tmp when dump_pdf_extract is enabled" do
    Dir.mktmpdir do |root|
      llm = instance_double(MoneyGone::LlmClient)
      extractor = instance_double(MoneyGone::PdfStatementExtractor)
      text = "--- Pagina 1 ---\nLINEA OCR"
      allow(extractor).to receive(:extract).with("/tmp/x.pdf").and_return(text)
      allow(llm).to receive(:parse_statement_transactions).with(text).and_return(
        [{ booking_date: "2026-05-10", amount_raw: "-1,00", description_raw: "x" }]
      )

      described_class.new(
        llm_client: llm,
        pdf_extractor: extractor,
        project_root: root,
        dump_pdf_extract: true
      ).import_pdf("/tmp/x.pdf", bank_id: "b1")

      glob = Dir.glob(File.join(root, "tmp", "money-gone-pdf-extract", "*.txt"))
      expect(glob.size).to eq(1)
      expect(File.read(glob.first, encoding: Encoding::UTF_8)).to eq(text)
    end
  end

  it "raises when PDF import is requested without an LLM client" do
    expect do
      described_class.new.import_pdf("/tmp/y.pdf", bank_id: "x")
    end.to raise_error(ArgumentError, /llm_client/)
  end
end
