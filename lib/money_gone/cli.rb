# frozen_string_literal: true

require 'thor'

require_relative 'cli/bank_spec_parser'
require_relative 'cli/llm_exit_handler'
require_relative 'cli/support'
require_relative 'cli/analyze_command'
require_relative 'stub_llm'

module MoneyGone
  class CLI < Thor
    include Cli::Support
    include Cli::AnalyzeCommand

    desc 'analyze BANK_SPEC ...', 'Analyze bank statements (each BANK_SPEC is bank_id:path)'
    long_desc <<~LONG.strip
      Provide one or more bank_id:path pairs, for example:

        money-gone analyze a:spec/fixtures/bank_a.csv b:spec/fixtures/bank_b.xlsx

      Use --stub to classify without calling LM Studio (tests / offline).

      With a running LM Studio, categorization uses the OpenAI-compatible API from config/lmstudio.yml
      (override with --lmstudio-url and --model).

      By default the LM asks only category + confidence (faster). Use --category-suggestions to also ask for
      rationale and ideas for new category labels (more tokens / slower).

      Use --jobs N for parallel HTTP calls (VRAM/CPU permitting; see categorization.parallel_jobs in config/rules.yml).
    LONG
    option :stub, type: :boolean, default: false, desc: 'Use stub categorizer (no HTTP)'
    option :verbose, type: :boolean, aliases: '-v', default: false,
                     desc: 'List each movement with category and LM raw label'
    option :category_suggestions, type: :boolean, default: false,
                                  desc: 'Ask LM for rationale + optional new-category ideas (slower)'
    option :jobs, aliases: '-j', type: :numeric,
                  desc: 'Parallel LM categorize requests (default: rules.yml parallel_jobs)'
    option :model, type: :string, desc: 'Override model id from config'
    option :lmstudio_url, type: :string, desc: 'Override LM Studio base URL (e.g. http://127.0.0.1:1234/v1)'
    def analyze(*bank_specs)
      run_analyze(bank_specs)
    rescue StandardError => e
      Cli::LlmExitHandler.handle(e)
    end

    desc 'chat', 'Interactive chat with the local LM Studio model (OpenAI-compatible /v1/chat/completions)'
    option :model, type: :string, desc: 'Override model id from config'
    option :lmstudio_url, type: :string, desc: 'Override LM Studio base URL'
    def chat
      run_chat_command
    rescue StandardError => e
      handle_chat_error(e)
    end

    private

    def run_chat_command
      client = build_llm(stub: false, model: option_string(:model), lmstudio_url: option_string(:lmstudio_url))
      say "Modello: #{client.model}. Digita exit o quit per uscire.", :green
      run_chat_loop(client)
    end

    def handle_chat_error(error)
      Cli::LlmExitHandler.handle(
        error,
        interrupt_exit: lambda {
          say("\nCiao.", :yellow)
          exit 0
        }
      )
    end
  end
end
