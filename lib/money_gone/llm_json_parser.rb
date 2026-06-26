# frozen_string_literal: true

require 'json'

module MoneyGone
  module LlmJsonParser
    module_function

    def extract_json_object(text, parse_json:)
      raw = text.to_s.strip
      return '{}' if raw.empty?

      return raw if json_object?(raw, parse_json:)

      raw = strip_markdown_fence(raw)
      return raw if json_object?(raw, parse_json:)

      extract_braced_span(raw) || raw
    end

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
