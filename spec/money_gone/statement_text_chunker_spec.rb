# frozen_string_literal: true

require "spec_helper"

RSpec.describe MoneyGone::StatementTextChunker do
  around do |example|
    saved = ENV.fetch("MONEY_GONE_STATEMENT_CHUNK_BYTES", nil)
    ENV.delete("MONEY_GONE_STATEMENT_CHUNK_BYTES")
    example.run
    if saved
      ENV["MONEY_GONE_STATEMENT_CHUNK_BYTES"] = saved
    else
      ENV.delete("MONEY_GONE_STATEMENT_CHUNK_BYTES")
    end
  end

  it "returns a single chunk when under the byte limit" do
    t = "--- Pagina 1 ---\nfoo"
    expect(described_class.chunk(t, max_chars: 10_000)).to eq([t])
  end

  it "merges pages until the byte limit is exceeded" do
    p1 = "--- Pagina 1 ---\n" + ("x" * 100)
    p2 = "--- Pagina 2 ---\n" + ("y" * 100)
    text = "#{p1}\n\n#{p2}"
    chunks = described_class.chunk(text, max_chars: 180)
    expect(chunks.size).to eq(2)
    expect(chunks.first).to include("Pagina 1")
    expect(chunks.last).to include("Pagina 2")
  end

  it "hard-splits oversized pages" do
    big = "z" * 500
    text = "--- Pagina 1 ---\n#{big}"
    chunks = described_class.chunk(text, max_chars: 120)
    expect(chunks.size).to be >= 2
    expect(chunks.join).to include("Pagina 1")
  end

  describe ".effective_max_bytes" do
    it "prefers ENV over yaml hint and default" do
      ENV["MONEY_GONE_STATEMENT_CHUNK_BYTES"] = "4096"
      expect(described_class.effective_max_bytes(2000)).to eq(4096)
    end

    it "uses yaml hint when ENV unset" do
      expect(described_class.effective_max_bytes(4500)).to eq(4500)
    end

    it "falls back to DEFAULT_MAX_CHARS" do
      expect(described_class.effective_max_bytes(nil)).to eq(described_class::DEFAULT_MAX_CHARS)
    end

    it "clamps to MIN_BYTES" do
      expect(described_class.effective_max_bytes(100)).to eq(described_class::MIN_BYTES)
    end
  end
end
