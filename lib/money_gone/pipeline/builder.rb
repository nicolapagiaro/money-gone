# frozen_string_literal: true

require_relative 'step'
require_relative 'steps/import_step'
require_relative 'steps/detect_transfers_step'
require_relative 'steps/rule_categorize_step'
require_relative 'steps/llm_categorize_step'
require_relative 'steps/aggregate_step'

module MoneyGone
  class Pipeline
    class Builder
      def self.build(root:, llm:, loader: nil, include_category_suggestions: false, parallel_jobs: nil)
        context = build_context(root, llm, loader, include_category_suggestions, parallel_jobs)
        new(steps: build_steps(context))
      end

      def self.build_context(root, llm, loader, include_category_suggestions, parallel_jobs)
        loader ||= ConfigLoader.new(root: root)
        cfg = loader.load_all
        {
          root: root,
          llm: llm,
          cfg: cfg,
          rules: cfg[:rules] || {},
          include_category_suggestions: include_category_suggestions,
          parallel_jobs: parallel_jobs
        }
      end

      def self.build_steps(context)
        [
          Steps::ImportStep.new(root: context.fetch(:root)),
          Steps::DetectTransfersStep.new(transfer_rules: context.fetch(:rules)['transfer'] || {}),
          rule_categorize_step(context),
          llm_categorize_step(context),
          Steps::AggregateStep.new
        ]
      end

      def self.rule_categorize_step(context)
        Steps::RuleCategorizeStep.new(
          categories: context.fetch(:cfg)[:categories],
          includes_rules: context.fetch(:rules).dig('categorization', 'description_category_includes')
        )
      end

      def self.llm_categorize_step(context)
        rules = context.fetch(:rules)
        Steps::LlmCategorizeStep.new(
          categories: context.fetch(:cfg)[:categories],
          llm: context.fetch(:llm),
          confidence_threshold: categorization_confidence_threshold(rules),
          include_suggestions: context.fetch(:include_category_suggestions),
          parallel_jobs: categorization_parallel_jobs(rules, context.fetch(:parallel_jobs))
        )
      end

      def self.categorization_confidence_threshold(rules)
        thr = rules.dig('categorization', 'confidence_threshold')
        threshold = thr.nil? ? 0.45 : thr.to_f
        threshold <= 0.0 ? 0.45 : threshold
      end

      def self.categorization_parallel_jobs(rules, parallel_jobs)
        jobs = parallel_jobs.nil? ? rules.dig('categorization', 'parallel_jobs')&.to_i : parallel_jobs.to_i
        jobs = 1 if jobs.nil? || jobs < 1
        [jobs, 16].min
      end

      def initialize(steps:)
        @steps = steps
      end

      def run(banks)
        import_step, transfer_step, rule_step, llm_step, aggregate_step = @steps
        movements = import_step.call(banks)
        movements = transfer_step.call(movements)
        movements = rule_step.call(movements)
        movements = llm_step.call(movements)
        aggregate_step.call(movements)
      end
    end
  end
end
