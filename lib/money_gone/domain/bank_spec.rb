# frozen_string_literal: true

module MoneyGone
  module Domain
    class BankSpec
      class Invalid < StandardError; end

      attr_reader :bank_id, :path

      def initialize(bank_id:, path:)
        @bank_id = bank_id.to_s.strip
        @path = path.to_s.strip
        validate!
      end

      def to_h
        { bank_id: @bank_id, path: @path }
      end

      private

      def validate!
        raise Invalid, 'bank_id is required' if @bank_id.empty?
        raise Invalid, 'path is required' if @path.empty?
      end
    end
  end
end
