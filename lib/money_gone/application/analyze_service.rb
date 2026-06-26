# frozen_string_literal: true

require_relative 'bank_spec_parser'
require_relative 'llm_factory'

module MoneyGone
  module Application
    class AnalyzeService
      def initialize(root: Dir.pwd, llm_factory: nil, report: nil)
        @root = root
        @llm_factory = llm_factory || LlmFactory.new(root: root)
        @report = report || Infrastructure::ConsoleReport.new
      end

      def call(bank_specs, options)
        banks = BankSpecParser.parse(bank_specs).map(&:to_h)
        ensure_llm_available!
        result = run_pipeline(banks, options)
        @report.render(result, verbose: options[:verbose])
      end

      private

      def run_pipeline(banks, options)
        Pipeline::Builder.build(**pipeline_build_options(options)).run(banks)
      end

      def pipeline_build_options(options)
        {
          root: @root,
          llm: build_llm(options),
          include_category_suggestions: options[:category_suggestions],
          parallel_jobs: options[:jobs]
        }
      end

      def build_llm(options)
        @llm_factory.build(
          stub: options[:stub],
          model: options[:model],
          lmstudio_url: options[:lmstudio_url]
        )
      end

      def ensure_llm_available!
        return unless ENV['MONEY_GONE_LLM_FAIL'] == '1'

        raise Infrastructure::LlmClient::UnavailableError, 'LM Studio unavailable'
      end
    end
  end
end
