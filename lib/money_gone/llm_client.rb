# frozen_string_literal: true

require 'json'
require 'ruby_llm'

require_relative 'llm_prompts'
require_relative 'llm_json_parser'
require_relative 'llm_response_normalizer'
require_relative 'llm_chat_session'

module MoneyGone
  class LlmClient
    class UnavailableError < StandardError; end
    class ResponseError < StandardError; end

    UNAVAILABLE_ERRORS = [
      RubyLLM::ServiceUnavailableError,
      RubyLLM::UnauthorizedError,
      RubyLLM::ForbiddenError
    ].freeze

    NETWORK_ERRORS = [
      Faraday::ConnectionFailed,
      Faraday::TimeoutError,
      Errno::ECONNREFUSED,
      Errno::ETIMEDOUT,
      Errno::EHOSTUNREACH,
      SocketError
    ].freeze

    def initialize(base_url:, model:, timeout_s: 60)
      @base_url = base_url.to_s.chomp('/')
      @model = model
      @timeout_s = timeout_s
      @llm_context = build_llm_context
    end

    attr_reader :base_url, :model, :timeout_s

    def parse_json(text)
      JSON.parse(text)
    end

    def chat(messages, temperature: 0.35)
      with_llm_errors do
        msgs = messages.map { |message| LlmChatSession.normalize_message(message) }
        session = llm_chat(temperature: temperature)
        LlmChatSession.populate(session, msgs)
        text = LlmResponseNormalizer.extract_content(LlmChatSession.complete(session, msgs))
        raise ResponseError, 'empty response from model' if text.strip.empty?

        text
      end
    end

    def categorize(row, allowed_categories:, include_suggestions: false)
      with_llm_errors do
        ask_categorization(row, allowed_categories, include_suggestions:)
      end
    rescue JSON::ParserError => e
      raise ResponseError, "invalid JSON from model: #{e.message}"
    end

    def ping
      with_llm_errors do
        provider = RubyLLM::Providers::OpenAI.new(@llm_context.config)
        models = provider.list_models
        { 'data' => models.map { |entry| { 'id' => entry.id } } }
      end
    end

    private

    def ask_categorization(row, allowed_categories, include_suggestions:)
      user = LlmPrompts.format_transaction_for_prompt(row)
      system, user_block, temp, schema = categorization_prompt_bundle(
        user,
        allowed_categories.join(', '),
        include_suggestions:
      )
      session = llm_chat(temperature: temp).with_schema(schema)
      session.add_message(role: :system, content: system)
      response = session.ask(user_block)
      LlmResponseNormalizer.normalize_categorization(response.content, parse_json: method(:parse_json))
    end

    def with_llm_errors
      yield
    rescue *UNAVAILABLE_ERRORS, *NETWORK_ERRORS => e
      raise UnavailableError, e.message
    rescue RubyLLM::Error => e
      raise ResponseError, e.message
    end

    def categorization_prompt_bundle(user, categories_line, include_suggestions:)
      return fast_prompt_bundle(user, categories_line) unless include_suggestions

      full_prompt_bundle(user, categories_line)
    end

    def fast_prompt_bundle(user, categories_line)
      [LlmPrompts.system_prompt_fast(categories_line),
       LlmPrompts.user_block_fast(user, categories_line),
       0.2,
       LlmPrompts.categorization_schema_fast]
    end

    def full_prompt_bundle(user, categories_line)
      [LlmPrompts.system_prompt_full(categories_line),
       LlmPrompts.user_block_full(user, categories_line),
       0.28,
       LlmPrompts.categorization_schema_full]
    end

    def build_llm_context
      RubyLLM.context do |config|
        config.openai_api_key = ENV.fetch('OPENAI_API_KEY', 'lm-studio')
        config.openai_api_base = base_url
        config.request_timeout = timeout_s
        config.max_retries = 0
      end
    end

    def llm_chat(temperature:)
      @llm_context.chat(model: model, provider: :openai, assume_model_exists: true)
                  .with_temperature(temperature)
    end
  end
end
