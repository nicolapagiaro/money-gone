# frozen_string_literal: true

require_relative '../../domain/category_catalog'

module MoneyGone
  class Pipeline
    module Steps
      class RuleCategorizeStep < Step
        def initialize(categories:, includes_rules:)
          super()
          @catalog = Domain::CategoryCatalog.new(categories)
          @includes_rules = includes_rules
        end

        def call(movements, **_context)
          return movements unless @includes_rules.is_a?(Hash) && @includes_rules.any?

          movements.map { |movement| apply_to_movement(movement) }
        end

        private

        def apply_to_movement(movement)
          return movement if movement.transfer? || movement.categorized?

          text = movement.description_clean.to_s
          text = movement.description_raw.to_s if text.strip.empty?

          category = @catalog.match_description_includes(text, @includes_rules)
          return movement unless category

          movement.apply_rule_category!(category: category)
        end
      end
    end
  end
end
