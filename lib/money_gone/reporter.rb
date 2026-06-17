# frozen_string_literal: true

module MoneyGone
  class Reporter
    def render(result, verbose: false)
      ft = result[:flow_totals]
      if ft
        puts "Riepilogo flussi (esclusi i giroconti riconosciuti)"
        puts "- Totale entrate: #{format('%.2f', ft.fetch(:entrate, 0.0).to_f)}"
        puts "- Totale uscite: #{format('%.2f', ft.fetch(:uscite, 0.0).to_f)}"
        puts "- Flusso di cassa netto (entrate − |uscite|): #{format('%.2f', ft.fetch(:netto, 0.0).to_f)}"
        puts ""
      end

      puts "Totali per categoria"
      result[:totals].each do |category, total|
        puts "- #{category}: #{format('%.2f', total)}"
        top_expenses_for_category(result[:rows], category).each do |row|
          date = row[:booking_date].to_s
          description = row[:description_clean].to_s.strip
          description = row[:description_raw].to_s.strip if description.empty?
          description = "-" if description.empty?
          puts "    #{date} | #{description} | #{format('%.2f', row[:amount_signed].to_f)}"
        end
      end
      puts "\nGiroconti riconosciuti"
      result[:transfers].each do |t|
        source = t[:transfer_source_bank] || t[:bank_id] || "-"
        destination = t[:transfer_destination_bank] || t[:bank_id] || "-"
        amount = format("%.2f", t[:amount_signed].to_f)
        puts "- #{t[:id]} | #{source} -> #{destination} | #{amount}"
      end
      puts "\nNuove categorie suggerite"
      result[:suggestions].each { |k, v| puts "- #{k}: #{v}" }

      return unless verbose && result[:rows]

      puts "\nDettaglio movimenti (esclusi giroconti)"
      result[:rows].each do |t|
        next if t[:excluded_from_spending]

        conf = t[:category_confidence]
        conf_s = conf.nil? ? "-" : format("%.2f", conf.to_f)
        raw = t[:category_raw].to_s.empty? ? "-" : t[:category_raw]
        puts "  - #{t[:id]} | categoria: #{t[:category]} | importo: #{t[:amount_signed]}"
        puts "    LM raw: #{raw} | confidenza: #{conf_s}"
        puts "    #{t[:description_clean]}" if t[:description_clean]
      end
    end

    private

    def top_expenses_for_category(rows, category, limit: 3)
      Array(rows)
        .select do |row|
          !row[:excluded_from_spending] &&
            (row[:category] || "Altro") == category &&
            row[:amount_signed].to_f.negative?
        end
        .sort_by { |row| row[:amount_signed].to_f }
        .first(limit)
    end
  end
end
