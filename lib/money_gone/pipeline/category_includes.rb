# frozen_string_literal: true

module MoneyGone
  class Pipeline
    class CategoryIncludes
      def initialize(categories)
        @categories = categories
      end

      def apply(rows, includes_rules)
        mapping = normalize_includes_mapping(includes_rules)
        return rows if mapping.empty?

        rows.map { |row| apply_to_row(row, mapping) }
      end

      private

      def apply_to_row(row, mapping)
        return row if skip_includes_rule?(row)

        folded = folded_description(row)
        return row if folded.strip.empty?

        category = category_for_match(folded, mapping)
        return row unless category

        merge_includes_category(row, category)
      end

      def skip_includes_rule?(row)
        row[:excluded_from_spending] || row[:category]
      end

      def folded_description(row)
        text = row[:description_clean].to_s
        text = row[:description_raw].to_s if text.strip.empty?
        fold_ascii(text).downcase
      end

      def category_for_match(folded, mapping)
        match = mapping.find { |needle, _category| folded.include?(needle) }
        return nil unless match

        resolve_category(match[1])
      end

      def merge_includes_category(row, category)
        row.merge(
          category: category,
          category_raw: category,
          category_confidence: 1.0,
          category_source: 'rule_includes',
          skip_llm_categorization: true
        )
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

      def resolve_category(label)
        return nil if label.to_s.strip.empty?

        target = label.to_s.strip
        @categories.find { |cat| cat == target } ||
          @categories.find { |cat| fold_ascii(cat).downcase == fold_ascii(target).downcase }
      end

      def fold_ascii(str)
        str.to_s.unicode_normalize(:nfd).gsub(/\p{M}/u, '')
      end
    end
  end
end
