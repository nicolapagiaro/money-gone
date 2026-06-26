# frozen_string_literal: true

# Composition root — layered requires
#
# domain/
require_relative 'money_gone/domain/category_catalog'
require_relative 'money_gone/domain/movement'
require_relative 'money_gone/domain/analysis_result'
require_relative 'money_gone/domain/bank_spec'
require_relative 'money_gone/domain/categorization_backend'
require_relative 'money_gone/domain/report_renderer'
require_relative 'money_gone/domain/report_aggregator'

# application/
require_relative 'money_gone/application/bank_spec_parser'
require_relative 'money_gone/application/llm_factory'
require_relative 'money_gone/application/exit_code_mapper'
require_relative 'money_gone/application/analyze_service'
require_relative 'money_gone/application/chat_service'

# infrastructure/
require_relative 'money_gone/infrastructure/llm_client'
require_relative 'money_gone/infrastructure/stub_llm'
require_relative 'money_gone/infrastructure/console_report'

# import boundary + domain services
require_relative 'money_gone/config_loader'
require_relative 'money_gone/importer'
require_relative 'money_gone/models/transaction'
require_relative 'money_gone/normalizer'
require_relative 'money_gone/schema_mapper'
require_relative 'money_gone/transfer_detector'
require_relative 'money_gone/categorizer'

# pipeline/
require_relative 'money_gone/pipeline/step'
require_relative 'money_gone/pipeline'

# cli
require_relative 'money_gone/cli'
