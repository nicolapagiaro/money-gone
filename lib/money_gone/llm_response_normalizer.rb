# frozen_string_literal: true

require 'json'

module MoneyGone
  module LlmResponseNormalizer
    module_function

    def normalize_categorization(content, parse_json:)
      hash =
        if content.is_a?(Hash)
          content.transform_keys(&:to_s)
        else
          parse_json.call(LlmJsonParser.extract_json_object(content.to_s, parse_json: parse_json))
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
  end
end
