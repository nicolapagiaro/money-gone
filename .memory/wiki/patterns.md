# Coding Patterns

*Document established coding conventions, file structures, and UI/UX patterns here.*

## Layered Architecture

```
lib/money_gone/
  domain/           # Movement, CategoryCatalog, AnalysisResult, BankSpec, contracts
  application/      # AnalyzeService, ChatService, LlmFactory, ExitCodeMapper
  infrastructure/   # LlmClient, StubLlm, ConsoleReport, llm/* collaborators
  pipeline/         # Step interface, Builder, steps/*
  cli.rb            # Thin Thor facade → application services
```

`lib/money_gone.rb` is the **composition root**: requires by layer, no business logic.

## Domain Model

- **`Domain::Movement`**: enrichment lifecycle (`exclude_as_transfer!`, `apply_rule_category!`, `apply_llm_category!`); replaces mutable transaction hashes in the pipeline.
- **`Domain::AnalysisResult`**: wraps `totals`, `flow_totals`, `transfers`, `suggestions`, `movements`; `rows` aliases `movements` for report compatibility.
- **`Domain::CategoryCatalog`**: single source for label resolve/fold and `description_category_includes` matching.
- **`Domain::CategorizationBackend`**: contract implemented by `Infrastructure::LlmClient` and `Infrastructure::StubLlm`.
- **`Domain::ReportRenderer`**: port; `Infrastructure::ConsoleReport` renders with injectable `io` (default `$stdout`).
- **`Domain::ReportAggregator`**: category/flow totals and suggestions from `Movement` collections.

## Pipeline (Open/Closed)

`Pipeline::Builder.build(...).run(banks)` assembles five steps:

| Step | Output |
|------|--------|
| `Steps::ImportStep` | `[Movement]` from bank specs |
| `Steps::DetectTransfersStep` | movements with transfer flags |
| `Steps::RuleCategorizeStep` | rule-based pre-categorization via `CategoryCatalog` |
| `Steps::LlmCategorizeStep` | LLM categorization via `Categorizer` |
| `Steps::AggregateStep` | `AnalysisResult` via `ReportAggregator` |

`Pipeline.run` delegates to `Builder` for backward-compatible call sites.

## Application Layer

- **`AnalyzeService`**: parse bank specs → build LLM → run pipeline → `ConsoleReport`.
- **`ChatService`**: REPL loop with injectable io; extracted from CLI.
- **`LlmFactory`**: stub/env/config resolution for LLM client.
- **`ExitCodeMapper`**: sole module that calls `exit N` for CLI error mapping.
- **`BankSpecParser`**: raises `ParseError`; domain `BankSpec::Invalid` for validation.

## Infrastructure / LLM

- **`Infrastructure::LlmClient`**: facade with injected `Llm::PromptBuilder`, `SessionDriver`, `ResponseParser`.
- Categorization uses `with_schema` (`json_schema` response format; required by LM Studio).
- `MoneyGone::LlmClient` / `MoneyGone::StubLlm` are backward-compatible aliases.

## Data Handling Conventions

- Import boundary: `Importer` → `Models::Transaction` → `Movement.from_transaction`.
- Text folding for matching: unicode NFD + combining mark removal in `CategoryCatalog`.
- Deterministic-before-LLM: rule step sets `skip_llm_categorization`; confidence gate forces `"Altro"` below threshold.
- Transfer exclusion: `excluded_from_spending` + reason/group metadata; totals respect `counts_toward_spending?`.

## Testing Style

- RSpec unit + integration; `spec/support/movement_helpers.rb` for `build_movement`.
- `console_report_spec.rb` uses `StringIO` instead of global stdout capture.
- Offline-safe tests via `--stub`, fixtures, and `MONEY_GONE_LLM_FAIL`.
