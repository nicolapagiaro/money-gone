# frozen_string_literal: true

module MoneyGone
  module Cli
    module AnalyzeCommand
      def run_analyze(bank_specs)
        banks = BankSpecParser.parse(bank_specs, say: method(:say))
        ensure_llm_available!
        render_analyze_result(banks)
      end

      private

      def render_analyze_result(banks)
        result = Pipeline.run(
          banks,
          root: Dir.pwd,
          llm: analyze_llm,
          include_category_suggestions: options[:category_suggestions],
          parallel_jobs: option_numeric(:jobs)
        )
        Reporter.new.render(result, verbose: options[:verbose])
      end

      def analyze_llm
        build_llm(
          stub: options[:stub],
          model: option_string(:model),
          lmstudio_url: option_string(:lmstudio_url)
        )
      end

      def ensure_llm_available!
        return unless ENV['MONEY_GONE_LLM_FAIL'] == '1'

        raise MoneyGone::LlmClient::UnavailableError, 'LM Studio unavailable'
      end
    end
  end
end
