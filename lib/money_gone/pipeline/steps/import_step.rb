# frozen_string_literal: true

module MoneyGone
  class Pipeline
    module Steps
      class ImportStep < Step
        def initialize(root:)
          super()
          @root = root
        end

        def call(banks, **_context)
          importer = Importer.new
          transactions = banks.flat_map do |bank|
            path = File.expand_path(bank[:path], @root)
            importer.import_path(path, bank_id: bank[:bank_id])
          end
          transactions.map { |txn| Domain::Movement.from_transaction(txn) }
        end
      end
    end
  end
end
