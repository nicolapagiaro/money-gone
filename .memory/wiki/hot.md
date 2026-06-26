# Hot Cache

*This file is read first by agents to get immediate context. Agents must update this at the end of every session.*

## Current State
- **OOP domain refactor complete** (2026-06-26): layered `domain/`, `application/`, `infrastructure/`, `pipeline/steps/`.
- Core domain: `Movement`, `AnalysisResult`, `CategoryCatalog`, `BankSpec`, `ReportAggregator`.
- Application: `AnalyzeService`, `ChatService`, `LlmFactory`, `ExitCodeMapper`, `BankSpecParser`.
- Pipeline: `Builder` + 5 steps (`Import`, `DetectTransfers`, `RuleCategorize`, `LlmCategorize`, `Aggregate`).
- LLM cluster under `infrastructure/llm/` (`PromptBuilder`, `SessionDriver`, `ResponseParser`); `LlmClient` uses injected collaborators.
- Reporting: `ConsoleReport` implements `ReportRenderer` with injectable `io`.
- `lib/money_gone.rb` is the composition root with layered requires.
- RuboCop: target 0 offenses; RSpec: 45 examples green.
- Removed legacy: `CategoryLabelMatcher`, `Reporter`, `cli/*` mixins, top-level LLM modules, `pipeline/category_includes`, `pipeline/totals_calculator`.

## Immediate Next Steps
- [ ] Add concrete bug entries in `bugs.md` whenever a failing case is reproduced and include fix/workaround status.
- [ ] Keep wiki entries synchronized when categorization/transfer logic changes.
- [ ] Consider adding `rubocop` to CI if not already wired.
- [ ] Optional: teach `Llm::PromptBuilder` to accept `Movement` directly (drop `Movement#to_h` at LLM boundary).
