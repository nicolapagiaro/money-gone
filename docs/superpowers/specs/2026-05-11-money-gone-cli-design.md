# Money Gone CLI Design (Ruby + LM Studio)

## Objective

Build a local Ruby CLI that ingests bank statements from two banks (`.csv` or `.xlsx`), normalizes transactions, detects internal transfers (giroconti), classifies remaining transactions into fixed categories, and prints a terminal-only report.

The CLI always depends on a locally running LM Studio instance via OpenAI-compatible APIs, using `qwen3.2 8b` as default model.

## Scope (V1)

- CLI-only interface.
- Input formats: CSV and Excel.
- Bank-specific schemas may change over time.
- Category system:
  - fixed category set for official reporting,
  - optional suggestions for new categories (not auto-adopted).
- Transfer detection:
  - deterministic rules first,
  - LLM fallback for borderline cases.
- Output only in terminal (no CSV/JSON export in V1).

## High-Level Architecture

Pipeline:

1. Import input files.
2. Map variable source schemas to canonical schema.
3. Normalize values and text.
4. Detect internal transfers (rules first, then LLM fallback).
5. Categorize non-transfer transactions (rules + LLM).
6. Aggregate totals by category.
7. Render terminal report.

Core components:

- `Importer`
- `SchemaMapper`
- `Normalizer`
- `TransferDetector`
- `Categorizer`
- `LlmClient`
- `Reporter`

## CLI Contract

Primary command:

- `money-gone analyze --bank <bank_id>:<file_path> [--bank <bank_id>:<file_path> ...]`

Core options:

- `--model` (default `qwen3.2 8b`)
- `--lmstudio-url` (local OpenAI-compatible endpoint)
- `--date-from`
- `--date-to`
- `--verbose`

Behavior:

- LM Studio is mandatory.
- If LM Studio is unavailable, command exits with non-zero code and clear error message.

## Canonical Data Model

Each imported transaction is normalized to:

- `id` (internal UUID/string)
- `bank_id`
- `source_file`
- `booking_date`
- `value_date` (optional)
- `amount_signed` (negative = outgoing, positive = incoming)
- `currency`
- `description_raw`
- `description_clean`
- `counterparty_hint` (optional)
- `transfer_group_id` (optional)
- `excluded_from_spending` (boolean)
- `excluded_reason` (optional, e.g. `internal_transfer`)
- `category`
- `category_confidence` (optional)
- `category_source` (`rule` or `llm`)
- `suggested_new_category` (optional)

## Input Handling: CSV/XLSX with Variable Schemas

### Importer

- Accept `.csv` and `.xlsx`.
- Detect encoding and delimiters for CSV where feasible.
- Provide explicit errors per file on parse failure.

### SchemaMapper

- Maps bank-specific column names to canonical fields.
- Works with flexible matching (exact, normalized, and alias-based matching).
- If mapping confidence is low, fail with actionable message showing detected columns.

### Normalizer

- Normalize dates to a standard format.
- Normalize decimal separators and sign conventions.
- Clean transaction text (trim, collapse spaces, lowercase helper field).
- Keep original raw description for auditability.

## Internal Transfer (Giroconto) Detection

Goal: avoid counting both sides of internal money movement as spending/income.

### Deterministic phase

Candidate matching between different banks using:

- opposite signed amount with numeric tolerance,
- booking date window (default 0-2 days),
- text similarity and keywords (transfer/giroconto/bonifico patterns),
- optional hints (counterparty/name/IBAN fragments if available).

Score each pair in `[0,1]`:

- `>= high_threshold`: mark as transfer automatically.
- `between thresholds`: send to LLM fallback.
- `< low_threshold`: do not mark.

### LLM fallback phase

- Send only compact candidate payload (target transaction + top candidates).
- Force structured JSON response:
  - `is_transfer` (bool)
  - `confidence` (0..1)
  - `reason` (short)
  - `matched_transaction_id` (nullable)
- If response invalid: retry with stricter formatting prompt (max retries limited).
- Safety rule: if returned confidence is below threshold, do not auto-exclude.

### Post-action

For confirmed transfers:

- assign same `transfer_group_id` to paired records,
- set `excluded_from_spending=true`,
- set `excluded_reason=internal_transfer`.

## Categorization Design

### Category policy

Official category set is fixed and config-driven (`config/categories.yml`).

Initial V1 set:

- `Casa`
- `Spesa`
- `Trasporti`
- `Salute`
- `Utenze`
- `Abbonamenti`
- `Svago`
- `Ristoranti`
- `Shopping`
- `Stipendio`
- `Investimenti`
- `Altro`

### Classification flow

1. Rule-based mapping first (keyword and merchant mapping).
2. LLM for ambiguous/unmapped records.
3. Hard validation on returned category:
   - if not in allowed set, final category falls back to `Altro`.
4. Optional `suggested_new_category` collected for reporting only.

### LLM output contract for categorization

Strict JSON fields:

- `category` (must be one of fixed set)
- `confidence` (0..1)
- `rationale_short`
- `suggested_new_category` (nullable string)

If confidence below threshold:

- assign `Altro`,
- keep suggestion if present.

## LM Studio Integration

Single `LlmClient` abstraction:

- OpenAI-compatible chat/completions endpoint.
- Default model: `qwen3.2 8b`.
- Deterministic generation settings where possible (low temperature).
- Unified retry/timeout/error handling.

Configuration:

- `config/lmstudio.yml` for base URL, model, timeout, retry count.

## Reporting (Terminal Only)

Output sections:

1. Totals by category (excluding transfers).
2. Recognized transfers excluded from totals.
3. Suggested new categories with recurrence counts.

Optional verbose mode:

- show diagnostics (mapping decisions, fallback reasons, confidence thresholds).

## Error Handling and Exit Codes

- LM Studio unavailable -> clear message + non-zero exit.
- Invalid file format -> file-specific parse error.
- Ambiguous column mapping -> actionable message + detected headers.
- Invalid LLM JSON -> bounded retries, then deterministic fallback.

Exit conventions:

- `0` success
- `>0` failure

## Configuration Files

- `config/categories.yml`: fixed categories.
- `config/rules.yml`:
  - keyword/merchant rules,
  - transfer thresholds,
  - date windows,
  - amount tolerances,
  - confidence gates.
- `config/lmstudio.yml`: model and endpoint settings.

## Testing Strategy

### Unit tests

- date/amount normalization
- schema mapping behavior
- deterministic transfer scoring
- LLM response validation/parsing
- category validation/fallback logic

### Integration tests

- full pipeline with fixture data for two banks (`csv` + `xlsx`).
- expected transfer exclusions.
- expected category totals.

### Golden tests

- snapshot terminal report output for stable regression checks.

### Edge cases

- same amount multiple times in narrow date windows.
- mixed decimal/date formats.
- noisy/abbreviated descriptions.
- currency mismatches.

## Non-Goals (V1)

- GUI/web interface.
- persistent database.
- automatic adoption of new categories.
- bank API integrations.

## Future Extensions

- optional `--export csv/json`.
- interactive category approval workflow.
- per-bank learned schema profiles.
- richer transfer graphing/traceability.

## Open Decisions Resolved

- Interface: CLI only.
- Input schema variability: supported by adaptive mapper.
- Transfer detection: deterministic + LLM fallback.
- Categories: fixed set + suggestions.
- LM Studio dependency: mandatory in V1.
- Output: terminal only.

