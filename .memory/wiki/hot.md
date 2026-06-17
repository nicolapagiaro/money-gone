# Hot Cache

*This file is read first by agents to get immediate context. Agents must update this at the end of every session.*

## Current State
- MemWiki ingestion pass completed on 2026-06-17.
- MemWiki lint pass completed on 2026-06-17.
- Wiki core pages now reflect actual repository state:
  - `stack.md`: runtime, dependencies, layout, and LM integration.
  - `patterns.md`: service-object flow, normalization/matching patterns, transfer and categorization conventions, testing style.
  - `decisions.md`: recorded current architectural decisions and their trade-offs.
- `bugs.md` now contains baseline status plus current quirks/residual risks.
- Project is a Ruby CLI for bank statement ingestion, normalization, transfer detection, and category reporting with optional LM Studio classification.

## Immediate Next Steps
- [ ] Add concrete bug entries in `bugs.md` whenever a failing case is reproduced and include fix/workaround status.
- [ ] Keep wiki entries synchronized when categorization/transfer logic changes.
- [ ] Add ADR entries when new config flags or matching heuristics are introduced.
