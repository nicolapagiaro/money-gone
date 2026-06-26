# frozen_string_literal: true

module MoneyGone
  module Domain
    module ReportRenderer
      def render(_result, io:, verbose:)
        raise NotImplementedError
      end
    end
  end
end
