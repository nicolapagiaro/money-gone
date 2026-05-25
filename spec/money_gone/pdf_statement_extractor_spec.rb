# frozen_string_literal: true

require "spec_helper"

RSpec.describe MoneyGone::PdfStatementExtractor do
  let(:path) { "/nonexistent/dir/test_statement.pdf" }
  let(:expanded) { File.expand_path(path) }

  it "raises when the file does not exist" do
    expect do
      described_class.new.extract(path)
    end.to raise_error(MoneyGone::PdfStatementExtractor::Error, /non trovato/)
  end

  it "returns marked page text when the PDF has enough embedded text" do
    dense = ("MOVIMENTO BONIFICO XX " * 10).strip
    page = instance_double(PDF::Reader::Page, text: dense)
    reader = instance_double(PDF::Reader, pages: [page], page_count: 1)
    allow(File).to receive(:file?).with(expanded).and_return(true)
    allow(PDF::Reader).to receive(:new).with(expanded).and_return(reader)

    out = described_class.new.extract(path)
    expect(out).to include("--- Pagina 1 ---")
    expect(out).to include(dense)
  end

  it "removes blank and whitespace-only lines from extracted text" do
    filler = ("MOVIMENTO BONIFICO XX " * 10).strip
    page_text = "#{filler}\nriga uno\n\n  \n\nriga due"
    page = instance_double(PDF::Reader::Page, text: page_text)
    reader = instance_double(PDF::Reader, pages: [page], page_count: 1)
    allow(File).to receive(:file?).with(expanded).and_return(true)
    allow(PDF::Reader).to receive(:new).with(expanded).and_return(reader)

    out = described_class.new.extract(path)
    expect(out).to include("riga uno")
    expect(out).to include("riga due")
    expect(out).not_to include("\n\n")
    expect(out.lines(chomp: true)).not_to include("")
  end
end
