# frozen_string_literal: true

require_relative 'domain/category_catalog'

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
      @catalog = Domain::CategoryCatalog.new(categories)
      @llm = llm_client
      @confidence_threshold = confidence_threshold
      @include_suggestions = include_suggestions
      @parallel_jobs = [parallel_jobs.to_i, 1].max
    end

    def categorize(movements)
      return sequential_categorize(movements) if @parallel_jobs <= 1

      parallel_categorize(movements)
    end

    private

    def sequential_categorize(movements)
      movements.map { |movement| classify_movement(movement) }
    end

    def parallel_categorize(movements)
      out = movements.dup
      work = movements.each_with_index.reject { |(movement, _idx)| movement.transfer? }

      work.each_slice(@parallel_jobs) { |batch| process_batch(batch, out) }
      out
    end

    def process_batch(batch, out)
      threads = batch.map do |(movement, idx)|
        Thread.new { [idx, classify_movement(movement)] }
      end
      threads.each do |thr|
        idx, merged = thr.value
        out[idx] = merged
      end
    end

    def classify_movement(movement)
      return movement if movement.transfer? || movement.skip_llm_categorization

      movement.apply_llm_category!(catalog: @catalog, decision: llm_category_decision(movement))
    end

    def llm_category_decision(movement)
      decision = llm_decision_for(movement)
      Domain::Movement::LlmDecision.new(
        raw_label: decision['category'].to_s.strip,
        confidence: parse_confidence(decision['confidence']),
        suggestion: suggestion_for(decision),
        threshold: @confidence_threshold,
        include_suggestions: @include_suggestions
      )
    end

    def llm_decision_for(movement)
      normalize_decision(
        @llm.categorize(
          movement.to_h,
          allowed_categories: @categories,
          include_suggestions: @include_suggestions
        )
      )
    end

    def suggestion_for(decision)
      return nil unless @include_suggestions

      normalize_suggestion(decision['suggested_new_category'])
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
  end
end
