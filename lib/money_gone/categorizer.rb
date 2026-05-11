# frozen_string_literal: true

module MoneyGone
  class Categorizer
    def initialize(
      categories:,
      llm_client:,
      confidence_threshold: 0.45,
      include_suggestions: false,
      parallel_jobs: 1
    )
      @categories = categories
      @llm = llm_client
      @confidence_threshold = confidence_threshold
      @include_suggestions = include_suggestions
      @parallel_jobs = [parallel_jobs.to_i, 1].max
    end

    def categorize(transactions)
      return sequential_categorize(transactions) if @parallel_jobs <= 1

      parallel_categorize(transactions)
    end

    private

    def sequential_categorize(transactions)
      transactions.map { |tx| classify_row(tx) }
    end

    def parallel_categorize(transactions)
      out = transactions.dup
      work = transactions.each_with_index.reject { |(tx, _)| tx[:excluded_from_spending] }

      work.each_slice(@parallel_jobs) do |batch|
        batch.map do |(tx, idx)|
          Thread.new { [idx, classify_row(tx)] }
        end.each do |thr|
          idx, merged = thr.value
          out[idx] = merged
        end
      end

      out
    end

    def classify_row(tx)
      return tx if tx[:excluded_from_spending]

      decision = normalize_decision(
        @llm.categorize(
          tx,
          allowed_categories: @categories,
          include_suggestions: @include_suggestions
        )
      )
      raw_label = decision["category"].to_s.strip
      resolved = resolve_category(raw_label)
      confidence = parse_confidence(decision["confidence"])
      suggestion = @include_suggestions ? normalize_suggestion(decision["suggested_new_category"]) : nil

      category =
        if resolved.nil?
          "Altro"
        elsif confidence < @confidence_threshold
          "Altro"
        else
          resolved
        end

      suggestion = cleanup_suggestion(suggestion, category, resolved) if @include_suggestions

      tx.merge(
        category: category,
        suggested_new_category: suggestion,
        category_confidence: confidence,
        category_raw: raw_label
      )
    end

    def normalize_decision(hash)
      return {} unless hash.is_a?(Hash)

      hash.transform_keys(&:to_s)
    end

    def parse_confidence(value)
      return 0.75 if value.nil? || value.to_s.strip.empty?

      Float(value).clamp(0.0, 1.0)
    rescue ArgumentError, TypeError
      0.0
    end

    def resolve_category(label)
      return nil if label.strip.empty?

      s = label.strip
      @categories.find { |c| c == s } ||
        @categories.find { |c| same_label?(c, s) }
    end

    def same_label?(a, b)
      normalize_label(a) == normalize_label(b)
    end

    # Allinea risposte LM senza accenti (es. "caffe" vs "caffè") a config/categories.yml
    def normalize_label(s)
      fold_ascii(s).strip.downcase
    end

    def fold_ascii(str)
      str.to_s.unicode_normalize(:nfd).gsub(/\p{M}/u, "")
    end

    def normalize_suggestion(value)
      s = value.to_s.strip
      s.empty? ? nil : s
    end

    def cleanup_suggestion(suggestion, final_category, resolved)
      return nil if suggestion.nil?

      # Non ripetere la stessa etichetta già assegnata
      return nil if resolved && same_label?(suggestion, resolved)
      return nil if same_label?(suggestion, final_category)

      suggestion
    end
  end
end
