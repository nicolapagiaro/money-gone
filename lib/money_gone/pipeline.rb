# frozen_string_literal: true

require_relative 'stub_llm'
require_relative 'pipeline/totals_calculator'
require_relative 'pipeline/category_includes'

module MoneyGone
  class Pipeline
    def self.run(banks, llm:, root: Dir.pwd, **)
      new(root: root, llm: llm).run(banks, **)
    end

    def initialize(root:, llm:, loader: nil)
      @root = root
      @loader = loader || ConfigLoader.new(root: root)
      @llm = llm
    end

    def run(banks, include_category_suggestions: false, parallel_jobs: nil)
      cfg = @loader.load_all
      rows = import_all(banks)
      rows = detect_transfers(rows, cfg)
      rows = apply_category_rules(rows, cfg)
      rows = categorize_rows(rows, cfg, include_category_suggestions:, parallel_jobs:)
      build_result(rows)
    end

    private

    def import_all(banks)
      importer = Importer.new
      transactions = banks.flat_map do |bank|
        path = File.expand_path(bank[:path], @root)
        importer.import_path(path, bank_id: bank[:bank_id])
      end
      transactions.map { |txn| transaction_to_hash(txn) }
    end

    def detect_transfers(rows, cfg)
      transfer_rules = (cfg[:rules] || {})['transfer'] || {}
      TransferDetector.new.detect(rows, rules: transfer_rules)
      rows
    end

    def apply_category_rules(rows, cfg)
      includes_rules = (cfg[:rules] || {}).dig('categorization', 'description_category_includes')
      CategoryIncludes.new(cfg[:categories]).apply(rows, includes_rules)
    end

    def categorize_rows(rows, cfg, include_category_suggestions:, parallel_jobs:)
      rules = cfg[:rules] || {}
      Categorizer.new(
        categories: cfg[:categories],
        llm_client: @llm,
        confidence_threshold: categorization_confidence_threshold(rules),
        include_suggestions: include_category_suggestions,
        parallel_jobs: categorization_parallel_jobs(rules, parallel_jobs)
      ).categorize(rows)
    end

    def build_result(rows)
      calculator = TotalsCalculator.new
      {
        totals: calculator.totals(rows),
        flow_totals: calculator.flow_totals(rows),
        transfers: rows.select { |row| row[:excluded_from_spending] },
        suggestions: calculator.suggestions(rows),
        rows: rows
      }
    end

    def categorization_confidence_threshold(rules)
      thr = rules.dig('categorization', 'confidence_threshold')
      threshold = thr.nil? ? 0.45 : thr.to_f
      threshold <= 0.0 ? 0.45 : threshold
    end

    def categorization_parallel_jobs(rules, parallel_jobs)
      jobs = parallel_jobs.nil? ? rules.dig('categorization', 'parallel_jobs')&.to_i : parallel_jobs.to_i
      jobs = 1 if jobs.nil? || jobs < 1
      [jobs, 16].min
    end

    def transaction_to_hash(txn)
      {
        id: txn.id,
        bank_id: txn.bank_id,
        booking_date: txn.booking_date,
        amount_signed: txn.amount_signed,
        description_raw: txn.description_raw,
        description_clean: txn.description_clean
      }
    end
  end
end
