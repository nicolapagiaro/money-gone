# frozen_string_literal: true

module MoneyGone
  class Reporter
    def render(result, verbose: false)
      puts "Totali per categoria"
      result[:totals].each { |k, v| puts "- #{k}: #{format("%.2f", v)}" }
      puts "\nGiroconti riconosciuti"
      result[:transfers].each { |t| puts "- #{t[:id]} (#{t[:amount_signed]})" }
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
  end
end
