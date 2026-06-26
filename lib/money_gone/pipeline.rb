# frozen_string_literal: true

require_relative 'domain/movement'
require_relative 'domain/analysis_result'
require_relative 'pipeline/builder'

module MoneyGone
  class Pipeline
    def self.run(banks, llm:, root: Dir.pwd, **)
      Builder.build(root: root, llm: llm, **).run(banks)
    end
  end
end
