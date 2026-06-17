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
      importer = Importer.new
      txs = []
      banks.each do |b|
        path = File.expand_path(b[:path], @root)
        txs.concat(importer.import_path(path, bank_id: b[:bank_id]))
      end

      rows = txs.map { |t| transaction_to_hash(t) }
      rules = cfg[:rules] || {}
      transfer_rules = rules["transfer"] || {}
      TransferDetector.new.detect(rows, rules: transfer_rules)
      rows = apply_description_category_includes(rows, categories, rules.dig("categorization", "description_category_includes"))
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

    def apply_description_category_includes(rows, categories, includes_rules)
      mapping = normalize_includes_mapping(includes_rules)
      return rows if mapping.empty?

      rows.map do |row|
        next row if row[:excluded_from_spending]
        next row if row[:category]

        text = row[:description_clean].to_s
        text = row[:description_raw].to_s if text.strip.empty?
        folded = fold_ascii(text).downcase
        next row if folded.strip.empty?

        match = mapping.find { |needle, _| folded.include?(needle) }
        next row unless match

        category = resolve_category(match[1], categories)
        next row if category.nil?

        row.merge(
          category: category,
          category_raw: category,
          category_confidence: 1.0,
          category_source: "rule_includes",
          skip_llm_categorization: true
        )
      end
    end

    def normalize_includes_mapping(raw_mapping)
      return [] unless raw_mapping.is_a?(Hash)

      raw_mapping.each_with_object([]) do |(pattern, category), acc|
        needle = fold_ascii(pattern).downcase.strip
        cat = category.to_s.strip
        next if needle.empty? || cat.empty?

        acc << [needle, cat]
      end
    end

    def resolve_category(label, categories)
      return nil if label.to_s.strip.empty?

      target = label.to_s.strip
      categories.find { |c| c == target } ||
        categories.find { |c| fold_ascii(c).downcase == fold_ascii(target).downcase }
    end

    def fold_ascii(str)
      str.to_s.unicode_normalize(:nfd).gsub(/\p{M}/u, "")
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
    end
  end
end
