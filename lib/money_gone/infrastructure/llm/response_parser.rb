# frozen_string_literal: true

require 'json'

module MoneyGone
  module Infrastructure
    module Llm
      class ResponseParser
        def normalize_categorization(content, parse_json:)
          hash =
            if content.is_a?(Hash)
              content.transform_keys(&:to_s)
            else
              parse_json.call(extract_json_object(content.to_s, parse_json: parse_json))
            end
          hash['suggested_new_category'] = nil if hash['suggested_new_category'].to_s.strip.empty?
          hash['rationale_short'] = nil if hash['rationale_short'].to_s.strip.empty?
          hash
        end

        def extract_content(response)
          content = response.content
          return content if content.is_a?(String)
          return JSON.generate(content) if content.is_a?(Hash)

          content.to_s
        end

        def extract_json_object(text, parse_json:)
          raw = text.to_s.strip
          return '{}' if raw.empty?

          return raw if json_object?(raw, parse_json:)

          raw = strip_markdown_fence(raw)
          return raw if json_object?(raw, parse_json:)

          extract_braced_span(raw) || raw
        end

        private

        def json_object?(raw, parse_json:)
          parse_json.call(raw)
          true
        rescue JSON::ParserError
          false
        end

        def strip_markdown_fence(raw)
          return raw unless raw.start_with?('```')

          raw.sub(/\A```(?:json)?\s*/i, '').sub(/\s*```\z/, '').strip
        end

        def extract_braced_span(raw)
          raw.match(/\{.*\}/m)&.[](0)
        end
      end
    end
  end
end
