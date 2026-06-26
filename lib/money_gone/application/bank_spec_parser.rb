# frozen_string_literal: true

require_relative '../domain/bank_spec'

module MoneyGone
  module Application
    class BankSpecParser
      class ParseError < StandardError; end

      def self.parse(specs)
        raise ParseError, 'provide at least one bank_id:path' if specs.empty?

        specs.map { |spec| parse_spec(spec) }
      end

      def self.parse_spec(spec)
        bank_id, path = spec.split(':', 2)
        Domain::BankSpec.new(bank_id: bank_id, path: path)
      rescue Domain::BankSpec::Invalid
        raise ParseError, "invalid bank spec #{spec.inspect} (expected bank_id:path)"
      end
    end
  end
end
