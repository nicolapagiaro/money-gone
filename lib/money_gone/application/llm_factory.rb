# frozen_string_literal: true

module MoneyGone
  module Application
    class LlmFactory
      def initialize(root: Dir.pwd, loader: nil)
        @root = root
        @loader = loader || ConfigLoader.new(root: root)
      end

      def build(stub: false, model: nil, lmstudio_url: nil)
        return Infrastructure::StubLlm.new if stub || ENV['MONEY_GONE_STUB_LLM'] == '1'

        cfg = @loader.load_all[:lmstudio]
        Infrastructure::LlmClient.new(
          base_url: lmstudio_url || cfg.fetch('base_url'),
          model: model || cfg.fetch('model'),
          timeout_s: (cfg['timeout_s'] || 90).to_i
        )
      end
    end
  end
end
