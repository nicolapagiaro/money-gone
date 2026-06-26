# frozen_string_literal: true

module MoneyGone
  class CategoryLabelMatcher
    def initialize(categories)
      @categories = categories
    end

    def resolve(label)
      return nil if label.strip.empty?

      text = label.strip
      @categories.find { |cat| cat == text } ||
        @categories.find { |cat| same_label?(cat, text) }
    end

    def same_label?(left, right)
      normalize_label(left) == normalize_label(right)
    end

    private

    def normalize_label(text)
      fold_ascii(text).strip.downcase
    end

    def fold_ascii(str)
      str.to_s.unicode_normalize(:nfd).gsub(/\p{M}/u, '')
    end
  end
end
