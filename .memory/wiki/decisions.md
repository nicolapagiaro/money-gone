# Architectural Decisions

*Document major technical decisions, the rationale behind them, and alternatives considered.*

## 2026-06-17 - Local-first LLM via LM Studio (OpenAI-compatible)
- **Decision:** Integrate categorization against a local LM Studio endpoint (`/v1/chat/completions`) instead of a hosted API dependency.
- **Rationale:** Keep data local, reduce operational cost, and allow offline-like development with stub mode.
- **Trade-off:** Runtime quality/latency depends on user hardware and selected local model.

## 2026-06-17 - Service-object pipeline architecture for CLI app
- **Decision:** Keep domain logic in composable classes and use CLI mainly as an adapter layer.
- **Rationale:** Improves testability and isolates concerns (I/O, normalization, matching, classification, reporting).
- **Trade-off:** More files/objects than a monolithic script, but easier evolution.

## 2026-06-17 - Deterministic rules before probabilistic categorization
- **Decision:** Apply transfer and description include rules before LLM calls.
- **Rationale:** Avoid unnecessary token usage, reduce noise, and ensure known recurring transactions get stable categories.
- **Trade-off:** Rule maintenance burden grows with heterogeneous bank descriptions.

## 2026-06-17 - Confidence-threshold fallback to `Altro`
- **Decision:** Normalize uncertain LLM outputs by forcing low-confidence predictions to `Altro`.
- **Rationale:** Prevents overconfident misclassification from weaker/local models.
- **Trade-off:** Higher threshold improves precision but may increase uncategorized volume.

## 2026-06-17 - Transfer exclusion as first-class accounting signal
- **Decision:** Mark recognized internal transfers with explicit exclusion metadata and remove them from spending totals.
- **Rationale:** Prevents double counting and distorted spending/flow summaries across same-bank and cross-bank moves.
- **Trade-off:** Cross-bank heuristic (same date + opposite amount + tolerance) can produce false positives in edge cases.

