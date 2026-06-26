# frozen_string_literal: true

require_relative '../../domain/report_aggregator'

module MoneyGone
  class Pipeline
    module Steps
      class AggregateStep < Step
        def initialize(aggregator: Domain::ReportAggregator.new)
          super()
          @aggregator = aggregator
        end

        def call(movements, **_context)
          @aggregator.build_result(movements)
        end
      end
    end
  end
end
