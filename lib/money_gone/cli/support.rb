# frozen_string_literal: true

module MoneyGone
  module Cli
    module Support
      CHAT_EXIT_COMMANDS = %w[exit quit].freeze

      def build_llm(stub:, model:, lmstudio_url:)
        return StubLlm.new if stub || ENV['MONEY_GONE_STUB_LLM'] == '1'

        loader = ConfigLoader.new(root: Dir.pwd)
        cfg = loader.load_all[:lmstudio]
        MoneyGone::LlmClient.new(
          base_url: lmstudio_url || cfg.fetch('base_url'),
          model: model || cfg.fetch('model'),
          timeout_s: (cfg['timeout_s'] || 90).to_i
        )
      end

      def run_chat_loop(client)
        messages = [chat_system_message]
        loop do
          line = read_chat_line
          break if line.nil? || line.empty?
          break if CHAT_EXIT_COMMANDS.include?(line.downcase)

          append_chat_exchange(messages, client, line)
        end
      end

      def option_string(key)
        value = options[key]
        return nil if value.nil?

        text = value.to_s.strip
        text.empty? ? nil : text
      end

      def option_numeric(key)
        value = options[key]
        return nil if value.nil?

        number = value.to_i
        number.positive? ? number : nil
      end

      private

      def chat_system_message
        {
          role: 'system',
          content: 'Sei un assistente per finanza personale in italiano. Rispondi in modo chiaro e conciso.'
        }
      end

      def read_chat_line
        print '> '
        $stdout.flush
        line = $stdin.gets
        return nil if line.nil?

        line.strip
      end

      def append_chat_exchange(messages, client, line)
        messages << { role: 'user', content: line }
        reply = client.chat(messages, temperature: 0.5)
        say(reply.to_s)
        messages << { role: 'assistant', content: reply.to_s }
      end
    end
  end
end
