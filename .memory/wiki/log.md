# Work Log

*Append-only changelog. Agents must append a timestamped summary of their work here at the end of each session.*

## Initial Setup
- Project memory initialized via MemWiki.

## 2026-06-17 12:19 UTC+2 - /memwiki-ingest
- Executed full ingestion pass requested by slash command.
- Scanned repository structure, runtime files, core library classes, configs, and tests.
- Populated `stack.md` with concrete stack/runtime/dependency/layout information.
- Populated `patterns.md` with established architecture and implementation conventions.
- Populated `decisions.md` with key ADR-style entries and trade-offs inferred from current codebase.
- Updated `hot.md` with current project state and next operational wiki steps.

## 2026-06-17 12:21 UTC+2 - /memwiki-lint
- Performed MemWiki health check across `hot.md`, `index.md`, `stack.md`, `patterns.md`, `bugs.md`, `decisions.md`, and `log.md`.
- Identified empty `bugs.md` as the main knowledge gap.
- Added baseline bug registry content and documented current quirks/residual risks.
- Refreshed `hot.md` to include lint completion status and more actionable next steps.

## 2026-06-17 12:30 UTC+2 - LlmClient ruby_llm migration
- Added `ruby_llm` gem (~> 1.16) to `Gemfile`.
- Rewrote `lib/money_gone/llm_client.rb` to use `RubyLLM.context` + OpenAI provider against LM Studio `base_url`.
- Removed `Net::HTTP` transport; mapped `RubyLLM`/`Faraday` errors to existing `UnavailableError` / `ResponseError`.
- Updated `spec/money_gone/llm_client_spec.rb` to stub `llm_chat` instead of raw `chat`.
- Updated `stack.md`, `decisions.md`, and `hot.md`.

## 2026-06-17 12:45 UTC+2 - LM Studio json_schema fix
- Switched categorization from `response_format: json_object` to `with_schema` because LM Studio only accepts `json_schema` or `text`.

## 2026-06-26 - RuboCop cleanup (83 → 0 offenses)
- Added `.rubocop.yml` with `rubocop-performance`, `Metrics/BlockLength` exclude for `spec/**/*`.
- Refactored lib to satisfy Metrics cops without inline disables: extracted prompt/JSON/chat helpers from `LlmClient`, pipeline totals/category rules, CLI support modules, `CategoryLabelMatcher`, `StubLlm`, `TransferDetector::CrossBankMatcher`.
- `bundle exec rubocop`: 0 offenses on 39 files; `bundle exec rspec`: 36 examples green.
