# frozen_string_literal: true

module MoneyGone
  module Cli
    module BankSpecParser
      module_function

      def parse(bank_specs, say:)
        if bank_specs.empty?
          say.call('error: provide at least one bank_id:path', :red)
          exit 1
        end

        bank_specs.map { |spec| parse_spec(spec, say:) }
      end

      def parse_spec(spec, say:)
        bank_id, path = spec.split(':', 2)
        if bank_id.to_s.strip.empty? || path.to_s.strip.empty?
          say.call("error: invalid bank spec #{spec.inspect} (expected bank_id:path)", :red)
          exit 1
        end
        { bank_id: bank_id.strip, path: path.strip }
      end
    end
  end
end
