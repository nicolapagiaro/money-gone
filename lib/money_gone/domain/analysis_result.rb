# frozen_string_literal: true

module MoneyGone
  module Domain
    class AnalysisResult
      attr_reader :totals, :flow_totals, :transfers, :suggestions, :movements

      def initialize(totals:, flow_totals:, transfers:, suggestions:, movements:)
        @totals = totals
        @flow_totals = flow_totals
        @transfers = transfers
        @suggestions = suggestions
        @movements = movements
      end

      def rows
        movements
      end

      def [](key)
        key == :rows ? movements : public_send(key)
      rescue NoMethodError
        nil
      end

      def to_h
        {
          totals: totals,
          flow_totals: flow_totals,
          transfers: transfers,
          suggestions: suggestions,
          rows: movements
        }
      end
    end
  end
end
