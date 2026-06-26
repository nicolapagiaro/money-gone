# Hot Cache

*This file is read first by agents to get immediate context. Agents must update this at the end of every session.*

## Current State
- RuboCop cleanup completed on 2026-06-26: **0 offenses** on 39 files (`bundle exec rubocop`).
- `.rubocop.yml` includes `Metrics/BlockLength` exclude for `spec/**/*` only; no inline `rubocop:disable` in lib.
- Refactors extracted: `LlmPrompts`, `LlmJsonParser`, `LlmResponseNormalizer`, `LlmChatSession`, `CategoryLabelMatcher`, `StubLlm`, `Pipeline::TotalsCalculator`, `Pipeline::CategoryIncludes`, `Cli::BankSpecParser`, `Cli::LlmExitHandler`, `Cli::Support`, `Cli::AnalyzeCommand`, `TransferDetector::CrossBankMatcher`.
- `LlmClient` migrated from hand-rolled `Net::HTTP` to `ruby_llm` (~> 1.16) with per-instance `RubyLLM.context`.
- Public `LlmClient` API unchanged (`chat`, `categorize`, `ping`, same error classes for CLI exit codes).
- Categorization uses `with_schema` (`json_schema` response format; required by LM Studio).
- Full RSpec suite green (36 examples).

## Immediate Next Steps
- [ ] Add concrete bug entries in `bugs.md` whenever a failing case is reproduced and include fix/workaround status.
- [ ] Keep wiki entries synchronized when categorization/transfer logic changes.
- [ ] Consider adding `rubocop` to CI if not already wired.
