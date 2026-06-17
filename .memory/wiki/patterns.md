# Coding Patterns

*Document established coding conventions, file structures, and UI/UX patterns here.*

## Code Organization
- Namespace-first structure: classes are under `module MoneyGone` and split by responsibility (`Importer`, `Normalizer`, `SchemaMapper`, `TransferDetector`, `Categorizer`, `Pipeline`, `Reporter`).
- Pipeline orchestration pattern: `Pipeline.run` builds a linear flow (import -> normalize -> transfer detection -> rule pre-categorization -> LLM categorization -> totals/report payload).
- Thin CLI, explicit exit codes: CLI maps known failure classes to stable process exit codes and keeps heavy logic in library classes.

## Data Handling Conventions
- Canonical transaction hash/struct keys are symbol-based (`booking_date`, `amount_signed`, `description_raw`, `description_clean`).
- Import-time schema normalization: bank-specific headers are mapped by regex aliases and unicode-cleaned before matching.
- Defensive normalization: amount parsing strips locale artifacts (NBSP, thousands separators, decimal comma) and preserves signed values.
- Text folding for matching: accent-insensitive comparisons via unicode NFD + combining mark removal are used in category/rule matching.

## Categorization and Rule Layering
- Deterministic-before-LLM pattern: `description_category_includes` rules set category first and mark `skip_llm_categorization`.
- Confidence gate pattern: low-confidence LLM labels are forced to `"Altro"` via configurable threshold.
- Optional enrichment toggle: `include_category_suggestions` controls whether rationale/suggestion fields are requested (faster default path otherwise).
- Parallel batch pattern: categorization can run in bounded thread batches (`parallel_jobs`, capped to protect local resources).

## Transfer Detection Patterns
- Exclusion flag contract: transfer detection sets `excluded_from_spending` + reason/group metadata; downstream totals always respect this flag.
- Two-stage transfer recognition:
  1) description-rule matching (keyword/exact),
  2) cross-bank amount/date pairing with tolerance.

## Testing Style
- RSpec unit + integration coverage across each service object and CLI behavior.
- Fixture-driven input validation for CSV/XLSX ingestion and pipeline outcomes.
- Offline-safe tests via stubbed categorization (`--stub`, test fixtures, and failure env flags).

