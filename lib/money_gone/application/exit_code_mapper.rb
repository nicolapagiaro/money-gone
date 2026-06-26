# frozen_string_literal: true

module MoneyGone
  module Application
    module ExitCodeMapper
      module_function

      def handle(error, interrupt_exit: nil)
        return interrupt_exit.call if error.is_a?(Interrupt) && interrupt_exit

        dispatch_error(error)
      end

      def dispatch_error(error)
        case error
        when BankSpecParser::ParseError then parse_error_exit(error)
        when Infrastructure::LlmClient::UnavailableError then unavailable_exit(error)
        when Infrastructure::LlmClient::ResponseError then response_exit(error)
        when SchemaMapper::MappingError then mapping_exit(error)
        else
          warn "Unexpected error: #{error.message}"
          exit 1
        end
      end

      def parse_error_exit(error)
        warn "error: #{error.message}"
        exit 1
      end

      def unavailable_exit(error)
        warn "LM Studio unavailable: #{error.message}"
        exit 2
      end

      def response_exit(error)
        warn "LM Studio response error: #{error.message}"
        exit 4
      end

      def mapping_exit(error)
        warn "Schema mapping error: #{error.message}"
        exit 3
      end
    end
  end
end
