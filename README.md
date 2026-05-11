# Money Gone

Ruby CLI for normalizing multi-bank statements and building terminal reports (see `docs/superpowers/specs/`).

## Requirements

- Ruby 3.3+
- [Bundled gems](Gemfile), including `thor`, `csv`, `roo`

## Setup

```bash
bundle install
```

## LM Studio

1. Start [LM Studio](https://lmstudio.ai/) and load **Qwen 3.2 8B** (or your preferred model).
2. Enable the local server and OpenAI-compatible API.
3. Edit `config/lmstudio.yml` if your base URL or model name differs.

The `analyze` command currently uses a built-in stub classifier so you can run without a live server; wiring to LM Studio will use `LlmClient` and `config/lmstudio.yml` as the project evolves.

## Usage

Analyze one or more statements. Each argument is `bank_id:path` (paths are relative to the current directory).

```bash
bundle exec ruby bin/money-gone analyze a:path/to/bank_a.csv b:path/to/bank_b.xlsx
```

Example with the bundled fixtures:

```bash
bundle exec ruby bin/money-gone analyze a:spec/fixtures/bank_a.csv b:spec/fixtures/bank_b.xlsx
```

## Tests

```bash
bundle exec rspec -fd
```

## Exit codes

- `0` success
- `1` unexpected error
- `2` LM Studio unavailable (use `MONEY_GONE_LLM_FAIL=1` only for simulating failure in tests)
- `3` schema / column mapping error
