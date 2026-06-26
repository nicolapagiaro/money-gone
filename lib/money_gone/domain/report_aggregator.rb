# frozen_string_literal: true

module MoneyGone
  module Domain
    class ReportAggregator
      def totals(movements)
        movements.each_with_object(Hash.new(0.0)) do |movement, acc|
          next unless movement.counts_toward_spending?

          cat = movement.category || 'Altro'
          acc[cat] += movement.amount_signed.to_f
        end
      end

      def flow_totals(movements)
        entrate = 0.0
        uscite = 0.0
        movements.each do |movement|
          next unless movement.counts_toward_spending?

          amt = movement.amount_signed.to_f
          entrate += amt if amt.positive?
          uscite += amt if amt.negative?
        end
        { entrate: entrate, uscite: uscite, netto: entrate + uscite }
      end

      def suggestions(movements)
        movements.each_with_object(Hash.new(0)) do |movement, acc|
          suggestion = movement.suggested_new_category
          next if suggestion.nil? || suggestion.to_s.strip.empty?

          acc[suggestion] += 1
        end
      end

      def build_result(movements)
        AnalysisResult.new(
          totals: totals(movements),
          flow_totals: flow_totals(movements),
          transfers: movements.select(&:transfer?),
          suggestions: suggestions(movements),
          movements: movements
        )
      end
    end
  end
end
