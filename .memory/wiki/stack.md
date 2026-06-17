# Tech Stack

*Document the core technologies, versions, and deployment details here.*

## Runtime and Tooling
- Language: Ruby (required `>= 3.3.0` from `Gemfile`; `.ruby-version` present).
- Package manager: Bundler (`Gemfile`, `Gemfile.lock`).
- CLI framework: `thor`.
- Task runner: `rake` with default task wired to RSpec.
- Test framework: `rspec`.

## Data and File Processing
- Input formats: CSV (`csv`) and Excel (`roo` supporting `.xlsx`/`.xls`).
- Config format: YAML (`YAML.safe_load_file`) under `config/`.
- Core domain shape: `MoneyGone::Models::Transaction` struct.

## LLM Integration
- Provider mode: local LM Studio using OpenAI-compatible API.
- Transport: `net/http` with JSON payloads and explicit timeout handling.
- Config source: `config/lmstudio.yml` (`base_url`, `model`, `timeout_s`).
- Operational modes: live LM mode and deterministic stub mode (`--stub` / env flag).

## Project Layout
- Entrypoint: `bin/money-gone`.
- Library code: `lib/money_gone/`.
- Tests: `spec/money_gone/*_spec.rb` plus fixtures in `spec/fixtures/`.
- Supporting docs: `docs/superpowers/specs/` and `docs/superpowers/plans/`.

