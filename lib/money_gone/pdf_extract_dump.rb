# frozen_string_literal: true

require "fileutils"

module MoneyGone
  # Salva su disco il testo estratto dal PDF (nativo o OCR) prima del chunking → LLM, per ispezione manuale.
  module PdfExtractDump
    RELATIVE_DIR = File.join("tmp", "money-gone-pdf-extract").freeze

    # @return [String] path assoluto del file creato
    def self.write!(root:, bank_id:, source_path:, text:)
      root = File.expand_path(root)
      dir = File.join(root, RELATIVE_DIR)
      FileUtils.mkdir_p(dir)

      stamp = Time.now.strftime("%Y%m%d-%H%M%S")
      bank = sanitize(bank_id.to_s)
      bank = "bank" if bank.empty?
      base = sanitize(File.basename(source_path, ".*"))
      base = "extract" if base.empty?
      fname = "#{stamp}_#{bank}_#{base}.txt"
      path = File.join(dir, fname)
      File.write(path, text.to_s, encoding: Encoding::UTF_8)
      path
    end

    def self.sanitize(s)
      s.gsub(/[^\p{L}\w.-]+/u, "_").squeeze("_").delete_suffix("_").delete_prefix("_")
    end
    private_class_method :sanitize
  end
end
