# frozen_string_literal: true

module MoneyGone
  class Pipeline
    class TotalsCalculator
      def totals(rows)
        rows.each_with_object(Hash.new(0.0)) do |row, acc|
          next if row[:excluded_from_spending]

          cat = row[:category] || 'Altro'
          acc[cat] += row[:amount_signed].to_f
        end
      end

      def flow_totals(rows)
        entrate = 0.0
        uscite = 0.0
        rows.each do |row|
          next if row[:excluded_from_spending]

          amt = row[:amount_signed].to_f
          entrate += amt if amt.positive?
          uscite += amt if amt.negative?
        end
        { entrate: entrate, uscite: uscite, netto: entrate + uscite }
      end

      def suggestions(rows)
        rows.each_with_object(Hash.new(0)) do |row, acc|
          suggestion = row[:suggested_new_category]
          next if suggestion.nil? || suggestion.to_s.strip.empty?

          acc[suggestion] += 1
        end
      end
    end
  end
end
