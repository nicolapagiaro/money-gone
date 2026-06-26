# frozen_string_literal: true

module MoneyGone
  class Pipeline
    class Step
      def initialize(**); end

      def call(_input, **_context)
        raise NotImplementedError
      end
    end
  end
end
