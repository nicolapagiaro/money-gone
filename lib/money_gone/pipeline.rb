# frozen_string_literal: true

module MoneyGone
  class Pipeline
    def self.run(banks, root: Dir.pwd, llm:, **opts)
      new(root: root, llm: llm).run(banks, **opts)
    end

    def initialize(root:, llm:, loader: nil)
      @root = root
      @loader = loader || ConfigLoader.new(root: root)
      @llm = llm
    end

    def run(banks, include_category_suggestions: false, parallel_jobs: nil)
      cfg = @loader.load_all
      categories = cfg[:categories]
      importer = Importer.new(llm_client: @llm)
      txs = []
      banks.each do |b|
        path = File.expand_path(b[:path], @root)
        txs.concat(importer.import_path(path, bank_id: b[:bank_id]))
      end

      rows = txs.map { |t| transaction_to_hash(t) }
      TransferDetector.new.detect(rows)
      rules = cfg[:rules] || {}
      thr = rules.dig("categorization", "confidence_threshold")
      confidence_threshold = thr.nil? ? 0.45 : thr.to_f
      confidence_threshold = 0.45 if confidence_threshold <= 0.0

      pj = parallel_jobs.nil? ? rules.dig("categorization", "parallel_jobs")&.to_i : parallel_jobs.to_i
      pj = 1 if pj.nil? || pj < 1
      pj = [pj, 16].min

      rows = Categorizer.new(
        categories: categories,
        llm_client: @llm,
        confidence_threshold: confidence_threshold,
        include_suggestions: include_category_suggestions,
        parallel_jobs: pj
      ).categorize(rows)

      {
        totals: compute_totals(rows),
        flow_totals: compute_flow_totals(rows),
        transfers: rows.select { |r| r[:excluded_from_spending] },
        suggestions: compute_suggestions(rows),
        rows: rows
      }
    end

    private

    def transaction_to_hash(t)
      {
        id: t.id,
        bank_id: t.bank_id,
        booking_date: t.booking_date,
        amount_signed: t.amount_signed,
        description_raw: t.description_raw,
        description_clean: t.description_clean
      }
    end

    def compute_totals(rows)
      rows.each_with_object(Hash.new(0.0)) do |t, acc|
        next if t[:excluded_from_spending]

        cat = t[:category] || "Altro"
        acc[cat] += t[:amount_signed].to_f
      end
    end

    # Somme importo con segno contabile (+ entrate / - uscite), solo movimenti conteggiati in report (senza giroconti).
    def compute_flow_totals(rows)
      entrate = 0.0
      uscite = 0.0
      rows.each do |t|
        next if t[:excluded_from_spending]

        amt = t[:amount_signed].to_f
        if amt.positive?
          entrate += amt
        elsif amt.negative?
          uscite += amt
        end
      end
      { entrate: entrate, uscite: uscite, netto: entrate + uscite }
    end

    def compute_suggestions(rows)
      rows.each_with_object(Hash.new(0)) do |t, acc|
        s = t[:suggested_new_category]
        next if s.nil? || s.to_s.strip.empty?

        acc[s] += 1
      end
    end

    # Minimal stand-in so `analyze` works without a running LM Studio (tests / local dry run).
    class StubLlm
      def categorize(_tx, allowed_categories: [], **_)
        label =
          allowed_categories.find { |c| c.match?(/supermercato/i) } ||
          allowed_categories.reject { |c| c.to_s.strip.downcase == "altro" }.first ||
          "Altro"
        { "category" => label, "confidence" => 0.95, "suggested_new_category" => nil }
      end

      def parse_statement_transactions(_text)
        [
          {
            booking_date: "2026-05-01",
            amount_raw: "-15,50",
            description_raw: "MOVIMENTO STUB DA PDF"
          }
        ]
      end
    end
  end
end
