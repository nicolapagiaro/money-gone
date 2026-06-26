# frozen_string_literal: true

require 'json'
require 'ruby_llm'

require_relative '../domain/categorization_backend'
require_relative 'llm/prompt_builder'
require_relative 'llm/session_driver'
require_relative 'llm/response_parser'

module MoneyGone
  module Infrastructure
    class LlmClient
      include Domain::CategorizationBackend

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

      def initialize(base_url:, model:, timeout_s: 60, collaborators: {})
        @base_url = base_url.to_s.chomp('/')
        @model = model
        @timeout_s = timeout_s
        @prompt_builder = collaborators.fetch(:prompt_builder) { Llm::PromptBuilder.new }
        @session_driver = collaborators.fetch(:session_driver) { Llm::SessionDriver.new }
        @response_parser = collaborators.fetch(:response_parser) { Llm::ResponseParser.new }
        @llm_context = build_llm_context
      end

      attr_reader :base_url, :model, :timeout_s

      def parse_json(text)
        JSON.parse(text)
      end

      def chat(messages, temperature: 0.35)
        with_llm_errors do
          msgs = messages.map { |message| @session_driver.normalize_message(message) }
          session = llm_chat(temperature: temperature)
          @session_driver.populate(session, msgs)
          text = @response_parser.extract_content(@session_driver.complete(session, msgs))
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
        user = @prompt_builder.format_transaction_for_prompt(row)
        system, user_block, temp, schema = @prompt_builder.categorization_bundle(
          user,
          allowed_categories.join(', '),
          include_suggestions:
        )
        session = llm_chat(temperature: temp).with_schema(schema)
        session.add_message(role: :system, content: system)
        response = session.ask(user_block)
        @response_parser.normalize_categorization(response.content, parse_json: method(:parse_json))
      end

      def with_llm_errors
        yield
      rescue *UNAVAILABLE_ERRORS, *NETWORK_ERRORS => e
        raise UnavailableError, e.message
      rescue RubyLLM::Error => e
        raise ResponseError, e.message
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
end

# Backward-compatible alias for callers and specs
MoneyGone::LlmClient = MoneyGone::Infrastructure::LlmClient
