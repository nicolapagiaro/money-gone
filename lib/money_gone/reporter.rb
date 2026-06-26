# frozen_string_literal: true

module MoneyGone
  class Reporter
    def render(result, verbose: false)
      render_flow_totals(result[:flow_totals])
      render_category_totals(result[:rows], result[:totals])
      render_transfers(result[:transfers])
      render_suggestions(result[:suggestions])
      render_verbose_rows(result[:rows]) if verbose && result[:rows]
    end

    private

    def render_flow_totals(flow_totals)
      return unless flow_totals

      puts 'Riepilogo flussi (esclusi i giroconti riconosciuti)'
      puts "- Totale entrate: #{format_amount(flow_totals.fetch(:entrate, 0.0))}"
      puts "- Totale uscite: #{format_amount(flow_totals.fetch(:uscite, 0.0))}"
      puts "- Flusso di cassa netto (entrate − |uscite|): #{format_amount(flow_totals.fetch(:netto, 0.0))}"
      puts ''
    end

    def render_category_totals(rows, totals)
      puts 'Totali per categoria'
      totals.each do |category, total|
        puts "- #{category}: #{format_amount(total)}"
        expense_rows_for_category(rows, category).each do |row|
          puts "    #{render_category_line(row)}"
        end
      end
    end

    def render_category_line(row)
      date = row[:booking_date].to_s
      description = row_description(row)
      "#{date} | #{description} | #{format_amount(row[:amount_signed])}"
    end

    def row_description(row)
      description = row[:description_clean].to_s.strip
      description = row[:description_raw].to_s.strip if description.empty?
      description.empty? ? '-' : description
    end

    def render_transfers(transfers)
      puts "\nGiroconti riconosciuti"
      transfers.each do |transfer|
        source = transfer[:transfer_source_bank] || transfer[:bank_id] || '-'
        destination = transfer[:transfer_destination_bank] || transfer[:bank_id] || '-'
        amount = format_amount(transfer[:amount_signed])
        puts "- #{transfer[:id]} | #{source} -> #{destination} | #{amount}"
      end
    end

    def render_suggestions(suggestions)
      puts "\nNuove categorie suggerite"
      suggestions.each { |key, value| puts "- #{key}: #{value}" }
    end

    def render_verbose_rows(rows)
      puts "\nDettaglio movimenti (esclusi giroconti)"
      rows.each do |row|
        render_verbose_row(row) unless row[:excluded_from_spending]
      end
    end

    def render_verbose_row(row)
      conf = row[:category_confidence]
      conf_s = conf.nil? ? '-' : format('%.2f', conf.to_f)
      raw = row[:category_raw].to_s.empty? ? '-' : row[:category_raw]
      puts "  - #{row[:id]} | categoria: #{row[:category]} | importo: #{row[:amount_signed]}"
      puts "    LM raw: #{raw} | confidenza: #{conf_s}"
      puts "    #{row[:description_clean]}" if row[:description_clean]
    end

    def expense_rows_for_category(rows, category)
      Array(rows)
        .select { |row| expense_row_for_category?(row, category) }
        .sort_by { |row| row[:amount_signed].to_f }
        .first(3)
    end

    def expense_row_for_category?(row, category)
      !row[:excluded_from_spending] &&
        (row[:category] || 'Altro') == category &&
        row[:amount_signed].to_f.negative?
    end

    def format_amount(value)
      format('%.2f', value.to_f)
    end
  end
end
