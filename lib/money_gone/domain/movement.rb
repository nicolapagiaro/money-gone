# frozen_string_literal: true

module MoneyGone
  module Domain
    class Movement
      LlmDecision = Struct.new(
        :raw_label, :confidence, :suggestion, :threshold, :include_suggestions,
        keyword_init: true
      )

      SERIALIZABLE_KEYS = %i[
        id bank_id booking_date amount_signed description_raw description_clean raw
        category category_raw category_confidence category_source suggested_new_category
        excluded_from_spending excluded_reason transfer_group_id transfer_source_bank
        transfer_destination_bank skip_llm_categorization
      ].freeze

      attr_reader :id, :bank_id, :booking_date, :amount_signed, :description_raw, :description_clean, :raw
      attr_accessor :category, :category_raw, :category_confidence, :category_source, :suggested_new_category,
                    :excluded_from_spending, :excluded_reason, :transfer_group_id,
                    :transfer_source_bank, :transfer_destination_bank, :skip_llm_categorization

      def initialize(attrs = {})
        assign_core_fields(attrs)
        assign_enrichment_fields(attrs)
        @excluded_from_spending = attrs.fetch(:excluded_from_spending, false)
      end

      def transfer?
        excluded_from_spending
      end

      def categorized?
        !category.nil?
      end

      def counts_toward_spending?
        !excluded_from_spending
      end

      def exclude_as_transfer!(reason:, group_id:, source_bank:, destination_bank:)
        self.excluded_from_spending = true
        self.excluded_reason = reason
        self.transfer_group_id = group_id
        self.transfer_source_bank = source_bank
        self.transfer_destination_bank = destination_bank
        self
      end

      def apply_rule_category!(category:)
        self.category = category
        self.category_raw = category
        self.category_confidence = 1.0
        self.category_source = 'rule_includes'
        self.skip_llm_categorization = true
        self
      end

      def apply_llm_category!(catalog:, decision:)
        resolved = catalog.resolve(decision.raw_label)
        final_category = resolved.nil? || decision.confidence < decision.threshold ? 'Altro' : resolved
        self.category = final_category
        self.category_raw = decision.raw_label
        self.category_confidence = decision.confidence
        self.suggested_new_category = filtered_suggestion(
          decision.suggestion, final_category, resolved, catalog, decision.include_suggestions
        )
        self
      end

      def self.from_transaction(txn)
        new(
          id: txn.id,
          bank_id: txn.bank_id,
          booking_date: txn.booking_date,
          amount_signed: txn.amount_signed,
          description_raw: txn.description_raw,
          description_clean: txn.description_clean,
          raw: txn.raw
        )
      end

      def to_h
        SERIALIZABLE_KEYS.to_h { |key| [key, public_send(key)] }
      end

      private

      def assign_core_fields(attrs)
        @id = attrs[:id]
        @bank_id = attrs[:bank_id]
        @booking_date = attrs[:booking_date]
        @amount_signed = attrs[:amount_signed]
        @description_raw = attrs[:description_raw]
        @description_clean = attrs[:description_clean]
        @raw = attrs[:raw]
      end

      def assign_enrichment_fields(attrs)
        @category = attrs[:category]
        @category_raw = attrs[:category_raw]
        @category_confidence = attrs[:category_confidence]
        @category_source = attrs[:category_source]
        @suggested_new_category = attrs[:suggested_new_category]
        @excluded_reason = attrs[:excluded_reason]
        @transfer_group_id = attrs[:transfer_group_id]
        @transfer_source_bank = attrs[:transfer_source_bank]
        @transfer_destination_bank = attrs[:transfer_destination_bank]
        @skip_llm_categorization = attrs[:skip_llm_categorization]
      end

      def filtered_suggestion(suggestion, final_category, resolved, catalog, include_suggestions)
        return nil unless include_suggestions
        return nil if suggestion.nil?
        return nil if resolved && catalog.same_label?(suggestion, resolved)
        return nil if catalog.same_label?(suggestion, final_category)

        suggestion
      end
    end
  end
end
