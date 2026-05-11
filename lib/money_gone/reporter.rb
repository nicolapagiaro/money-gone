# frozen_string_literal: true

module MoneyGone
  class Reporter
    def render(result)
      puts "Totali per categoria"
      result[:totals].each { |k, v| puts "- #{k}: #{format("%.2f", v)}" }
      puts "\nGiroconti riconosciuti"
      result[:transfers].each { |t| puts "- #{t[:id]} (#{t[:amount_signed]})" }
      puts "\nNuove categorie suggerite"
      result[:suggestions].each { |k, v| puts "- #{k}: #{v}" }
    end
  end
end
