# frozen_string_literal: true

module MoneyGone
  module Domain
    class CategoryCatalog
      def initialize(labels)
        @labels = labels
      end

      def resolve(label)
        return nil if label.to_s.strip.empty?

        text = label.to_s.strip
        @labels.find { |cat| cat == text } ||
          @labels.find { |cat| same_label?(cat, text) }
      end

      def same_label?(left, right)
        normalize_label(left) == normalize_label(right)
      end

      def folded_text(text)
        fold_ascii(text).downcase
      end

      def match_description_includes(description, rules_hash)
        mapping = normalize_includes_mapping(rules_hash)
        return nil if mapping.empty?

        folded = folded_text(description)
        return nil if folded.strip.empty?

        match = mapping.find { |needle, _category| folded.include?(needle) }
        return nil unless match

        resolve(match[1])
      end

      private

      def normalize_label(text)
        folded_text(text).strip
      end

      def fold_ascii(str)
        str.to_s.unicode_normalize(:nfd).gsub(/\p{M}/u, '')
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
    end
  end
end
