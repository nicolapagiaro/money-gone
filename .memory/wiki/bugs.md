# Known Bugs & Quirks

*Document unresolved issues, edge cases, and weird system quirks here to prevent future agents from falling into the same traps.*

## 2026-06-17 - Current known issues
- No confirmed production bugs are currently recorded from repository evidence.

## Known Quirks / Residual Risks
- Cross-bank transfer detection can yield false positives because matching is heuristic (`same date` + `opposite amount` within tolerance) and does not use counterparty identity.
- Parallel categorization uses Ruby threads around network calls; high `parallel_jobs` on weak local hardware may degrade performance instead of improving throughput.
- LLM JSON responses are partially normalized/fenced-stripped; malformed local-model outputs still surface as response errors and can stop CLI analyze flow.

