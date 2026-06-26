# frozen_string_literal: true

require 'thor'

require_relative 'application/analyze_service'
require_relative 'application/chat_service'
require_relative 'application/exit_code_mapper'
require_relative 'application/llm_factory'

module MoneyGone
  class CLI < Thor
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
      Application::AnalyzeService.new.call(bank_specs, analyze_options)
    rescue StandardError => e
      Application::ExitCodeMapper.handle(e)
    end

    desc 'chat', 'Interactive chat with the local LM Studio model (OpenAI-compatible /v1/chat/completions)'
    option :model, type: :string, desc: 'Override model id from config'
    option :lmstudio_url, type: :string, desc: 'Override LM Studio base URL'
    def chat
      run_chat_session
    rescue StandardError => e
      handle_chat_error(e)
    end

    private

    def run_chat_session
      client = chat_client
      Application::ChatService.new.run(client, say: method(:say))
    end

    def chat_client
      Application::LlmFactory.new.build(
        stub: false,
        model: option_string(:model),
        lmstudio_url: option_string(:lmstudio_url)
      )
    end

    def handle_chat_error(error)
      Application::ExitCodeMapper.handle(
        error,
        interrupt_exit: lambda {
          say("\nCiao.", :yellow)
          exit 0
        }
      )
    end

    def analyze_options
      {
        stub: options[:stub],
        verbose: options[:verbose],
        category_suggestions: options[:category_suggestions],
        jobs: option_numeric(:jobs),
        model: option_string(:model),
        lmstudio_url: option_string(:lmstudio_url)
      }
    end

    def option_string(key)
      value = options[key]
      return nil if value.nil?

      text = value.to_s.strip
      text.empty? ? nil : text
    end

    def option_numeric(key)
      value = options[key]
      return nil if value.nil?

      number = value.to_i
      number.positive? ? number : nil
    end
  end
end
