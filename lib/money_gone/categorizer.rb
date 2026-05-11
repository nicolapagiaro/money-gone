# frozen_string_literal: true

module MoneyGone
  class Categorizer
    def initialize(categories:, llm_client:, confidence_threshold: 0.65)
      @categories = categories
      @llm = llm_client
      @confidence_threshold = confidence_threshold
    end

    def categorize(transactions)
      transactions.map do |tx|
        next tx if tx[:excluded_from_spending]

        decision = @llm.categorize(tx)
        category = decision["category"]
        category = "Altro" unless @categories.include?(category)
        category = "Altro" if decision["confidence"].to_f < @confidence_threshold
        tx.merge(category: category, suggested_new_category: decision["suggested_new_category"])
      end
    end
  end
end
