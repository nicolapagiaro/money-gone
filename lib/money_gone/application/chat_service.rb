# frozen_string_literal: true

module MoneyGone
  module Application
    class ChatService
      CHAT_EXIT_COMMANDS = %w[exit quit].freeze

      def initialize(output: $stdout, input: $stdin)
        @output = output
        @input = input
      end

      def run(client, say:)
        say.call("Modello: #{client.model}. Digita exit o quit per uscire.", :green)
        messages = [chat_system_message]
        loop do
          line = read_line
          break if line.nil? || line.empty?
          break if CHAT_EXIT_COMMANDS.include?(line.downcase)

          append_exchange(messages, client, line, say:)
        end
      end

      private

      def chat_system_message
        {
          role: 'system',
          content: 'Sei un assistente per finanza personale in italiano. Rispondi in modo chiaro e conciso.'
        }
      end

      def read_line
        @output.print '> '
        @output.flush
        line = @input.gets
        return nil if line.nil?

        line.strip
      end

      def append_exchange(messages, client, line, say:)
        messages << { role: 'user', content: line }
        reply = client.chat(messages, temperature: 0.5)
        say.call(reply.to_s)
        messages << { role: 'assistant', content: reply.to_s }
      end
    end
  end
end
