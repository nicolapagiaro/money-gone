# frozen_string_literal: true

module MoneyGone
  class Categorizer
    def initialize(categories:, llm_client:, confidence_threshold: 0.45)
      @categories = categories
      @llm = llm_client
      @confidence_threshold = confidence_threshold
    end

    def categorize(transactions)
      transactions.map do |tx|
        next tx if tx[:excluded_from_spending]

        decision = normalize_decision(@llm.categorize(tx, allowed_categories: @categories))
        raw_label = decision["category"].to_s.strip
        resolved = resolve_category(raw_label)
        confidence = parse_confidence(decision["confidence"])
        suggestion = normalize_suggestion(decision["suggested_new_category"])

        category =
          if resolved.nil?
            "Altro"
          elsif confidence < @confidence_threshold
            "Altro"
          else
            resolved
          end

        suggestion = cleanup_suggestion(suggestion, category, resolved)

        tx.merge(
          category: category,
          suggested_new_category: suggestion,
          category_confidence: confidence,
          category_raw: raw_label
        )
      end
    end

    private

    def normalize_decision(hash)
      return {} unless hash.is_a?(Hash)

      hash.transform_keys(&:to_s)
    end

    def parse_confidence(value)
      return 0.75 if value.nil? || value.to_s.strip.empty?

      Float(value).clamp(0.0, 1.0)
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

    def normalize_label(s)
      s.to_s.strip.downcase
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
