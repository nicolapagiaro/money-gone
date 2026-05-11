# frozen_string_literal: true

require "csv"
require "roo"

require_relative "models/transaction"
require_relative "normalizer"
require_relative "pdf_statement_extractor"
require_relative "schema_mapper"
require_relative "statement_text_chunker"

module MoneyGone
  class Importer
    def initialize(schema_mapper: SchemaMapper.new, normalizer: Normalizer.new, llm_client: nil,
                   pdf_extractor: nil, statement_chunk_bytes: nil)
      @schema_mapper = schema_mapper
      @normalizer = normalizer
      @llm_client = llm_client
      @pdf_extractor = pdf_extractor
      @statement_chunk_bytes = statement_chunk_bytes
    end

    def import_csv(path, bank_id: nil)
      CSV.read(path, headers: true).each_with_index.map do |row, index|
        build_transaction(row.to_h, bank_id:, index:)
      end
    end

    def import_path(path, bank_id: nil)
      ext = File.extname(path).downcase
      case ext
      when ".csv"
        import_csv(path, bank_id: bank_id)
      when ".xlsx", ".xls"
        import_spreadsheet(path, bank_id: bank_id)
      when ".pdf"
        import_pdf(path, bank_id: bank_id)
      else
        raise ArgumentError, "unsupported statement format: #{ext.inspect} (#{path})"
      end
    end

    def import_pdf(path, bank_id: nil)
      raise ArgumentError, "PDF richiede LM Studio: passare llm_client all'Importer" if @llm_client.nil?

      extractor = @pdf_extractor || PdfStatementExtractor.new
      full_text = extractor.extract(path)
      max_chars = StatementTextChunker.effective_max_bytes(@statement_chunk_bytes)
      chunks = StatementTextChunker.chunk(full_text, max_chars: max_chars)
      mapped_rows = chunks.flat_map { |chunk| @llm_client.parse_statement_transactions(chunk) }

      mapped_rows.each_with_index.map do |mapped, index|
        build_transaction_from_pdf_row(mapped, bank_id: bank_id, index: index)
      end
    end

    def import_spreadsheet(path, bank_id: nil)
      x = Roo::Spreadsheet.open(path)
      sheet = x.sheet(0)
      headers = sheet.row(1).map { |h| SchemaMapper.normalize_header_label(h) }
      (2..sheet.last_row).map do |i|
        row_values = sheet.row(i)
        row = headers.zip(row_values).to_h
        build_transaction(row, bank_id:, index: i - 2)
      end
    end

    private

    def build_transaction_from_pdf_row(mapped, bank_id:, index:)
      missing = %i[booking_date amount_raw description_raw].reject do |key|
        mapped[key] && !mapped[key].to_s.strip.empty?
      end
      if missing.any?
        raise MoneyGone::SchemaMapper::MappingError,
              "PDF/LLM: mancano #{missing.join(', ')} alla riga #{index + 1}"
      end

      normalized = @normalizer.normalize(mapped)

      Models::Transaction.new(
        id: transaction_id(bank_id, index),
        bank_id: bank_id,
        booking_date: normalized[:booking_date].to_s.strip,
        amount_signed: normalized[:amount_signed],
        description_raw: normalized[:description_raw].to_s.strip,
        description_clean: normalized[:description_clean],
        raw: mapped.transform_keys(&:to_s)
      )
    end

    def build_transaction(row, bank_id:, index:)
      mapped = @schema_mapper.map_row(row)
      missing = %i[booking_date amount_raw description_raw].reject do |key|
        mapped[key] && !mapped[key].to_s.strip.empty?
      end
      if missing.any?
        headers = row.keys.map(&:to_s).join(", ")
        raise MoneyGone::SchemaMapper::MappingError,
              "cannot map columns (missing #{missing.join(', ')}); headers were: #{headers}"
      end

      normalized = @normalizer.normalize(mapped)

      Models::Transaction.new(
        id: transaction_id(bank_id, index),
        bank_id: bank_id,
        booking_date: normalized[:booking_date],
        amount_signed: normalized[:amount_signed],
        description_raw: normalized[:description_raw],
        description_clean: normalized[:description_clean],
        raw: row
      )
    end

    def transaction_id(bank_id, index)
      [bank_id, index + 1].compact.join(":")
    end
  end
end
