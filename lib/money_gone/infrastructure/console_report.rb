# frozen_string_literal: true

require_relative '../domain/report_renderer'

module MoneyGone
  module Infrastructure
    class ConsoleReport
      include Domain::ReportRenderer

      def initialize(io: $stdout)
        @io = io
      end

      def render(result, io: nil, verbose: false)
        output = io || @io
        payload = result.is_a?(Domain::AnalysisResult) ? result.to_h : result
        render_flow_totals(output, payload[:flow_totals])
        render_category_totals(output, payload[:rows], payload[:totals])
        render_transfers(output, payload[:transfers])
        render_suggestions(output, payload[:suggestions])
        render_verbose_rows(output, payload[:rows]) if verbose && payload[:rows]
      end

      private

      def render_flow_totals(output, flow_totals)
        return unless flow_totals

        output.puts 'Riepilogo flussi (esclusi i giroconti riconosciuti)'
        output.puts "- Totale entrate: #{format_amount(flow_totals.fetch(:entrate, 0.0))}"
        output.puts "- Totale uscite: #{format_amount(flow_totals.fetch(:uscite, 0.0))}"
        output.puts "- Flusso di cassa netto (entrate − |uscite|): #{format_amount(flow_totals.fetch(:netto, 0.0))}"
        output.puts ''
      end

      def render_category_totals(output, rows, totals)
        output.puts 'Totali per categoria'
        totals.each do |category, total|
          output.puts "- #{category}: #{format_amount(total)}"
          expense_rows_for_category(rows, category).each do |row|
            output.puts "    #{render_category_line(row)}"
          end
        end
      end

      def render_category_line(row)
        date = row_field(row, :booking_date).to_s
        description = row_description(row)
        "#{date} | #{description} | #{format_amount(row_field(row, :amount_signed))}"
      end

      def row_description(row)
        description = row_field(row, :description_clean).to_s.strip
        description = row_field(row, :description_raw).to_s.strip if description.empty?
        description.empty? ? '-' : description
      end

      def render_transfers(output, transfers)
        output.puts "\nGiroconti riconosciuti"
        transfers.each do |transfer|
          source = row_field(transfer, :transfer_source_bank) || row_field(transfer, :bank_id) || '-'
          destination = row_field(transfer, :transfer_destination_bank) || row_field(transfer, :bank_id) || '-'
          amount = format_amount(row_field(transfer, :amount_signed))
          output.puts "- #{row_field(transfer, :id)} | #{source} -> #{destination} | #{amount}"
        end
      end

      def render_suggestions(output, suggestions)
        output.puts "\nNuove categorie suggerite"
        suggestions.each { |key, value| output.puts "- #{key}: #{value}" }
      end

      def render_verbose_rows(output, rows)
        output.puts "\nDettaglio movimenti (esclusi giroconti)"
        rows.each do |row|
          render_verbose_row(output, row) unless row_field(row, :excluded_from_spending)
        end
      end

      def render_verbose_row(output, row)
        conf = row_field(row, :category_confidence)
        conf_s = conf.nil? ? '-' : format('%.2f', conf.to_f)
        raw = row_field(row, :category_raw).to_s.empty? ? '-' : row_field(row, :category_raw)
        output.puts "  - #{row_field(row, :id)} | categoria: #{row_field(row, :category)} | importo: #{row_field(row, :amount_signed)}"
        output.puts "    LM raw: #{raw} | confidenza: #{conf_s}"
        description_clean = row_field(row, :description_clean)
        output.puts "    #{description_clean}" if description_clean
      end

      def expense_rows_for_category(rows, category)
        Array(rows)
          .select { |row| expense_row_for_category?(row, category) }
          .sort_by { |row| row_field(row, :amount_signed).to_f }
          .first(3)
      end

      def expense_row_for_category?(row, category)
        !row_field(row, :excluded_from_spending) &&
          (row_field(row, :category) || 'Altro') == category &&
          row_field(row, :amount_signed).to_f.negative?
      end

      def row_field(row, key)
        row.respond_to?(key) ? row.public_send(key) : row[key]
      end

      def format_amount(value)
        format('%.2f', value.to_f)
      end
    end
  end
end
