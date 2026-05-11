# frozen_string_literal: true

require "thor"

module MoneyGone
  class CLI < Thor
    desc "analyze BANK_SPEC ...", "Analyze bank statements (each BANK_SPEC is bank_id:path)"
    long_desc <<~LONG.strip
      Provide one or more bank_id:path pairs, for example:

        money-gone analyze a:spec/fixtures/bank_a.csv b:spec/fixtures/bank_b.xlsx
    LONG
    def analyze(*bank_specs)
      if bank_specs.empty?
        say("error: provide at least one bank_id:path", :red)
        exit 1
      end

      banks = bank_specs.map do |spec|
        bank_id, path = spec.split(":", 2)
        if bank_id.to_s.strip.empty? || path.to_s.strip.empty?
          say("error: invalid bank spec #{spec.inspect} (expected bank_id:path)", :red)
          exit 1
        end
        { bank_id: bank_id.strip, path: path.strip }
      end

      if ENV["MONEY_GONE_LLM_FAIL"] == "1"
        raise MoneyGone::LlmClient::UnavailableError, "LM Studio unavailable"
      end

      result = Pipeline.run(banks, root: Dir.pwd)
      Reporter.new.render(result)
    rescue MoneyGone::LlmClient::UnavailableError => e
      warn "LM Studio unavailable: #{e.message}"
      exit 2
    rescue MoneyGone::SchemaMapper::MappingError => e
      warn "Schema mapping error: #{e.message}"
      exit 3
    rescue StandardError => e
      warn "Unexpected error: #{e.message}"
      exit 1
    end
  end
end
