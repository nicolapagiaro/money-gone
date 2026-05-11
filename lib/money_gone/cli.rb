# frozen_string_literal: true

require "thor"

module MoneyGone
  class CLI < Thor
    desc "analyze BANK_SPEC ...", "Analyze bank statements (each BANK_SPEC is bank_id:path)"
    long_desc <<~LONG.strip
      Provide one or more bank_id:path pairs, for example:

        money-gone analyze a:spec/fixtures/bank_a.csv b:spec/fixtures/bank_b.xlsx

      Use --stub to classify without calling LM Studio (tests / offline).

      With a running LM Studio, categorization uses the OpenAI-compatible API from config/lmstudio.yml
      (override with --lmstudio-url and --model).
    LONG
    option :stub, type: :boolean, default: false, desc: "Use stub categorizer (no HTTP)"
    option :verbose, type: :boolean, aliases: "-v", default: false, desc: "List each movement with category and LM raw label"
    option :model, type: :string, desc: "Override model id from config"
    option :lmstudio_url, type: :string, desc: "Override LM Studio base URL (e.g. http://127.0.0.1:1234/v1)"
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

      llm = build_llm(stub: options[:stub], model: option_string(:model), lmstudio_url: option_string(:lmstudio_url))
      result = Pipeline.run(banks, root: Dir.pwd, llm: llm)
      Reporter.new.render(result, verbose: options[:verbose])
    rescue MoneyGone::LlmClient::UnavailableError => e
      warn "LM Studio unavailable: #{e.message}"
      exit 2
    rescue MoneyGone::LlmClient::ResponseError => e
      warn "LM Studio response error: #{e.message}"
      exit 4
    rescue MoneyGone::SchemaMapper::MappingError => e
      warn "Schema mapping error: #{e.message}"
      exit 3
    rescue StandardError => e
      warn "Unexpected error: #{e.message}"
      exit 1
    end

    desc "chat", "Interactive chat with the local LM Studio model (OpenAI-compatible /v1/chat/completions)"
    option :model, type: :string, desc: "Override model id from config"
    option :lmstudio_url, type: :string, desc: "Override LM Studio base URL"
    def chat
      client = build_llm(stub: false, model: option_string(:model), lmstudio_url: option_string(:lmstudio_url))
      say "Modello: #{client.model}. Digita exit o quit per uscire.", :green
      messages = [
        {
          role: "system",
          content: "Sei un assistente per finanza personale in italiano. Rispondi in modo chiaro e conciso."
        }
      ]
      loop do
        print "> "
        $stdout.flush
        line = $stdin.gets
        break if line.nil?

        line = line.strip
        break if line.empty?

        case line.downcase
        when "exit", "quit"
          break
        end

        messages << { role: "user", content: line }
        reply = client.chat(messages, temperature: 0.5)
        say(reply.to_s)
        messages << { role: "assistant", content: reply.to_s }
      end
    rescue MoneyGone::LlmClient::UnavailableError => e
      warn "LM Studio unavailable: #{e.message}"
      exit 2
    rescue MoneyGone::LlmClient::ResponseError => e
      warn "LM Studio response error: #{e.message}"
      exit 4
    rescue Interrupt
      say "\nCiao.", :yellow
      exit 0
    end

    no_commands do
      def build_llm(stub:, model:, lmstudio_url:)
        return Pipeline::StubLlm.new if stub || ENV["MONEY_GONE_STUB_LLM"] == "1"

        loader = ConfigLoader.new(root: Dir.pwd)
        cfg = loader.load_all[:lmstudio]
        MoneyGone::LlmClient.new(
          base_url: lmstudio_url || cfg.fetch("base_url"),
          model: model || cfg.fetch("model"),
          timeout_s: (cfg["timeout_s"] || 90).to_i
        )
      end

      # Thor may pass option defaults as empty string.
      def option_string(key)
        v = options[key]
        return nil if v.nil?

        s = v.to_s.strip
        s.empty? ? nil : s
      end
    end
  end
end
