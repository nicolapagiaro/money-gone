# frozen_string_literal: true

module MoneyGone
  class Pipeline
    module Steps
      class LlmCategorizeStep < Step
        def initialize(categories:, llm:, confidence_threshold:, include_suggestions:, parallel_jobs:)
          super()
          @categorizer = Categorizer.new(
            categories: categories,
            llm_client: llm,
            confidence_threshold: confidence_threshold,
            include_suggestions: include_suggestions,
            parallel_jobs: parallel_jobs
          )
        end

        def call(movements, **_context)
          @categorizer.categorize(movements)
        end
      end
    end
  end
end
