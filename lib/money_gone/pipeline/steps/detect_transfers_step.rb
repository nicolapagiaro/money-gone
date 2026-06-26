# frozen_string_literal: true

module MoneyGone
  class Pipeline
    module Steps
      class DetectTransfersStep < Step
        def initialize(transfer_rules:)
          super()
          @transfer_rules = transfer_rules
        end

        def call(movements, **_context)
          TransferDetector.new.detect(movements, rules: @transfer_rules)
        end
      end
    end
  end
end
