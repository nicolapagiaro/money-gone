# frozen_string_literal: true

module MoneyGone
  class StubLlm
    def categorize(_row, allowed_categories: [], **_)
      label =
        allowed_categories.find { |cat| cat.match?(/supermercato/i) } ||
        allowed_categories.reject { |cat| cat.to_s.strip.downcase == 'altro' }.first ||
        'Altro'
      { 'category' => label, 'confidence' => 0.95, 'suggested_new_category' => nil }
    end
  end
end
