# frozen_string_literal: true

require "json"

module MoneyGone
  class LlmClient
    def initialize(base_url:, model:, timeout_s: 30)
      @base_url = base_url
      @model = model
      @timeout_s = timeout_s
    end

    def parse_json(text)
      JSON.parse(text)
    end
  end
end
