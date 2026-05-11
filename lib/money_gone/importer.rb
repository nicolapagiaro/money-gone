# frozen_string_literal: true

require "csv"
require "roo"

require_relative "models/transaction"
require_relative "normalizer"
require_relative "schema_mapper"

module MoneyGone
  class Importer
    def initialize(schema_mapper: SchemaMapper.new, normalizer: Normalizer.new)
      @schema_mapper = schema_mapper
      @normalizer = normalizer
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
      else
        raise ArgumentError, "unsupported statement format: #{ext.inspect} (#{path})"
      end
    end

    def import_spreadsheet(path, bank_id: nil)
      x = Roo::Spreadsheet.open(path)
      sheet = x.sheet(0)
      headers = sheet.row(1).map { |h| h.to_s.strip }
      (2..sheet.last_row).map do |i|
        row_values = sheet.row(i)
        row = headers.zip(row_values).to_h
        build_transaction(row, bank_id:, index: i - 2)
      end
    end

    private

    def build_transaction(row, bank_id:, index:)
      mapped = @schema_mapper.map_row(row)
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
