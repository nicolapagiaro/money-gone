# frozen_string_literal: true

module MoneyGone
  module Infrastructure
    module Llm
      class SessionDriver
        def populate(session, msgs)
          prior = msgs[0...-1]
          last = msgs[-1]
          prior.each { |message| session.add_message(role: message[:role], content: message[:content]) }
          return unless last && last[:role] != :user

          msgs.each { |message| session.add_message(role: message[:role], content: message[:content]) }
        end

        def complete(session, msgs)
          last = msgs[-1]
          if last && last[:role] == :user
            session.ask(last[:content])
          else
            session.complete
          end
        end

        def normalize_message(message)
          hash = message.transform_keys(&:to_s)
          { role: hash['role'].to_sym, content: hash['content'] }
        end
      end
    end
  end
end
