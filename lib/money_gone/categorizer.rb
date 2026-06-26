# frozen_string_literal: true

require_relative 'category_label_matcher'

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
      @label_matcher = CategoryLabelMatcher.new(categories)
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
      transactions.map { |row| classify_row(row) }
    end

    def parallel_categorize(transactions)
      out = transactions.dup
      work = transactions.each_with_index.reject { |(row, _idx)| row[:excluded_from_spending] }

      work.each_slice(@parallel_jobs) { |batch| process_batch(batch, out) }
      out
    end

    def process_batch(batch, out)
      threads = batch.map do |(row, idx)|
        Thread.new { [idx, classify_row(row)] }
      end
      threads.each do |thr|
        idx, merged = thr.value
        out[idx] = merged
      end
    end

    def classify_row(row)
      return row if row[:excluded_from_spending] || row[:skip_llm_categorization]

      decision = llm_decision_for(row)
      raw_label = decision['category'].to_s.strip
      resolved = @label_matcher.resolve(raw_label)
      confidence = parse_confidence(decision['confidence'])
      suggestion = suggestion_for(decision)
      category = resolve_category_with_threshold(resolved, confidence)

      build_categorized_row(row, category:, suggestion:, confidence:, raw_label:)
    end

    def llm_decision_for(row)
      normalize_decision(
        @llm.categorize(
          row,
          allowed_categories: @categories,
          include_suggestions: @include_suggestions
        )
      )
    end

    def suggestion_for(decision)
      return nil unless @include_suggestions

      normalize_suggestion(decision['suggested_new_category'])
    end

    def resolve_category_with_threshold(resolved, confidence)
      resolved.nil? || confidence < @confidence_threshold ? 'Altro' : resolved
    end

    def build_categorized_row(row, category:, suggestion:, confidence:, raw_label:)
      suggestion = cleanup_suggestion(suggestion, category, resolved_from(raw_label)) if @include_suggestions
      row.merge(
        category: category,
        suggested_new_category: suggestion,
        category_confidence: confidence,
        category_raw: raw_label
      )
    end

    def resolved_from(raw_label)
      @label_matcher.resolve(raw_label)
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

    def normalize_suggestion(value)
      text = value.to_s.strip
      text.empty? ? nil : text
    end

    def cleanup_suggestion(suggestion, final_category, resolved)
      return nil if suggestion.nil?
      return nil if resolved && @label_matcher.same_label?(suggestion, resolved)
      return nil if @label_matcher.same_label?(suggestion, final_category)

      suggestion
    end
  end
end
