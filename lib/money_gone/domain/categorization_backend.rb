# frozen_string_literal: true

module MoneyGone
  module Domain
    module CategorizationBackend
      def categorize(_row_or_movement, allowed_categories:, include_suggestions: false)
        raise NotImplementedError
      end
    end
  end
end
