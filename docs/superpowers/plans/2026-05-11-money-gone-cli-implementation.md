# Money Gone CLI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Ruby CLI that imports multi-bank CSV/XLSX statements, detects internal transfers, classifies transactions with fixed categories + suggestions, and prints terminal reports using LM Studio.

**Architecture:** The CLI runs a deterministic-first pipeline (`import -> map -> normalize -> transfer-detect -> categorize -> report`). Rule engines handle stable cases, while LM Studio is used only for ambiguous transfer/categorization decisions through strict JSON contracts and validated parsing.

**Tech Stack:** Ruby 3.3+, `thor`, `csv`, `roo`, `dry-struct`, `dry-validation`, `rspec`, `webmock`, `vcr`, LM Studio OpenAI-compatible HTTP API.

---

## File Structure

- Create: `Gemfile`
- Create: `Rakefile`
- Create: `.rspec`
- Create: `bin/money-gone`
- Create: `lib/money_gone.rb`
- Create: `lib/money_gone/cli.rb`
- Create: `lib/money_gone/config_loader.rb`
- Create: `lib/money_gone/models/transaction.rb`
- Create: `lib/money_gone/importer.rb`
- Create: `lib/money_gone/schema_mapper.rb`
- Create: `lib/money_gone/normalizer.rb`
- Create: `lib/money_gone/transfer_detector.rb`
- Create: `lib/money_gone/categorizer.rb`
- Create: `lib/money_gone/llm_client.rb`
- Create: `lib/money_gone/reporter.rb`
- Create: `lib/money_gone/pipeline.rb`
- Create: `config/categories.yml`
- Create: `config/rules.yml`
- Create: `config/lmstudio.yml`
- Create: `spec/spec_helper.rb`
- Create: `spec/fixtures/bank_a.csv`
- Create: `spec/fixtures/bank_b.xlsx`
- Create: `spec/money_gone/schema_mapper_spec.rb`
- Create: `spec/money_gone/normalizer_spec.rb`
- Create: `spec/money_gone/transfer_detector_spec.rb`
- Create: `spec/money_gone/categorizer_spec.rb`
- Create: `spec/money_gone/llm_client_spec.rb`
- Create: `spec/money_gone/pipeline_integration_spec.rb`

### Task 1: Bootstrap Ruby CLI Project

**Files:**
- Create: `Gemfile`, `Rakefile`, `.rspec`, `bin/money-gone`, `lib/money_gone.rb`, `lib/money_gone/cli.rb`
- Test: `spec/spec_helper.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# spec/money_gone/cli_boot_spec.rb
require "spec_helper"
require "open3"

RSpec.describe "CLI boot" do
  it "shows help" do
    stdout, status = Open3.capture2("ruby bin/money-gone --help")
    expect(status.success?).to be(true)
    expect(stdout).to include("analyze")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/money_gone/cli_boot_spec.rb -fd`  
Expected: FAIL because executable and CLI classes are missing.

- [ ] **Step 3: Write minimal implementation**

```ruby
# lib/money_gone/cli.rb
require "thor"

module MoneyGone
  class CLI < Thor
    desc "analyze", "Analyze bank statements"
    def analyze
      puts "Not implemented yet"
    end
  end
end
```

```ruby
# bin/money-gone
#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "money_gone"
MoneyGone::CLI.start(ARGV)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/money_gone/cli_boot_spec.rb -fd`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Gemfile Rakefile .rspec bin/money-gone lib/money_gone.rb lib/money_gone/cli.rb spec/spec_helper.rb spec/money_gone/cli_boot_spec.rb
git commit -m "chore: bootstrap ruby cli skeleton"
```

### Task 2: Implement Config Loading

**Files:**
- Create: `lib/money_gone/config_loader.rb`, `config/categories.yml`, `config/rules.yml`, `config/lmstudio.yml`
- Test: `spec/money_gone/config_loader_spec.rb`

- [ ] **Step 1: Write the failing test**

```ruby
RSpec.describe MoneyGone::ConfigLoader do
  it "loads categories and rules from yaml" do
    loader = described_class.new(root: Dir.pwd)
    cfg = loader.load_all
    expect(cfg[:categories]).to include("Spesa", "Altro")
    expect(cfg[:rules]).to have_key("transfer")
    expect(cfg[:lmstudio]["model"]).to eq("qwen3.2 8b")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/money_gone/config_loader_spec.rb -fd`  
Expected: FAIL because loader/config files are missing.

- [ ] **Step 3: Write minimal implementation**

```ruby
# lib/money_gone/config_loader.rb
require "yaml"

module MoneyGone
  class ConfigLoader
    def initialize(root:)
      @root = root
    end

    def load_all
      {
        categories: YAML.load_file(File.join(@root, "config/categories.yml"))["categories"],
        rules: YAML.load_file(File.join(@root, "config/rules.yml")),
        lmstudio: YAML.load_file(File.join(@root, "config/lmstudio.yml"))
      }
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/money_gone/config_loader_spec.rb -fd`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/money_gone/config_loader.rb config/categories.yml config/rules.yml config/lmstudio.yml spec/money_gone/config_loader_spec.rb
git commit -m "feat: add config loader and default yaml configs"
```

### Task 3: Add Import + Schema Mapping + Normalization

**Files:**
- Create: `lib/money_gone/importer.rb`, `lib/money_gone/schema_mapper.rb`, `lib/money_gone/normalizer.rb`, `lib/money_gone/models/transaction.rb`
- Test: `spec/money_gone/schema_mapper_spec.rb`, `spec/money_gone/normalizer_spec.rb`

- [ ] **Step 1: Write failing tests**

```ruby
RSpec.describe MoneyGone::SchemaMapper do
  it "maps variable source headers to canonical keys" do
    row = { "Data operazione" => "2026-05-01", "Importo EUR" => "-12,50", "Descrizione" => "Supermercato" }
    mapped = described_class.new.map_row(row)
    expect(mapped).to include(:booking_date, :amount_raw, :description_raw)
  end
end
```

```ruby
RSpec.describe MoneyGone::Normalizer do
  it "normalizes amount and description" do
    tx = { amount_raw: "-12,50", description_raw: "  SUPER   MERCATO " }
    out = described_class.new.normalize(tx)
    expect(out[:amount_signed]).to eq(-12.5)
    expect(out[:description_clean]).to eq("super mercato")
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bundle exec rspec spec/money_gone/schema_mapper_spec.rb spec/money_gone/normalizer_spec.rb -fd`  
Expected: FAIL due to missing classes/methods.

- [ ] **Step 3: Write minimal implementation**

```ruby
# lib/money_gone/schema_mapper.rb
module MoneyGone
  class SchemaMapper
    HEADER_MAP = {
      /data/i => :booking_date,
      /importo|amount/i => :amount_raw,
      /descrizione|description/i => :description_raw
    }.freeze

    def map_row(row)
      out = {}
      row.each do |k, v|
        target = HEADER_MAP.find { |rx, _| rx.match?(k.to_s) }&.last
        out[target] = v if target
      end
      out
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bundle exec rspec spec/money_gone/schema_mapper_spec.rb spec/money_gone/normalizer_spec.rb -fd`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/money_gone/schema_mapper.rb lib/money_gone/normalizer.rb lib/money_gone/importer.rb lib/money_gone/models/transaction.rb spec/money_gone/schema_mapper_spec.rb spec/money_gone/normalizer_spec.rb
git commit -m "feat: add mapper importer and normalizer core"
```

### Task 4: Implement LM Studio Client with Strict JSON Parsing

**Files:**
- Create: `lib/money_gone/llm_client.rb`
- Test: `spec/money_gone/llm_client_spec.rb`

- [ ] **Step 1: Write failing test**

```ruby
RSpec.describe MoneyGone::LlmClient do
  it "parses strict JSON response for categorization" do
    client = described_class.new(base_url: "http://localhost:1234/v1", model: "qwen3.2 8b")
    payload = '{"category":"Spesa","confidence":0.91,"rationale_short":"market","suggested_new_category":null}'
    expect(client.parse_json(payload)["category"]).to eq("Spesa")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/money_gone/llm_client_spec.rb -fd`  
Expected: FAIL because client does not exist.

- [ ] **Step 3: Write minimal implementation**

```ruby
# lib/money_gone/llm_client.rb
require "json"
require "net/http"

module MoneyGone
  class LlmClient
    def initialize(base_url:, model:, timeout_s: 30)
      @base_url = base_url
      @model = model
      @timeout_s = timeout_s
    end

    def parse_json(text)
      JSON.parse(text)
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/money_gone/llm_client_spec.rb -fd`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/money_gone/llm_client.rb spec/money_gone/llm_client_spec.rb
git commit -m "feat: add lm studio client and json parser"
```

### Task 5: Implement Transfer Detection (Rules + LLM Fallback)

**Files:**
- Create: `lib/money_gone/transfer_detector.rb`
- Test: `spec/money_gone/transfer_detector_spec.rb`

- [ ] **Step 1: Write failing tests**

```ruby
RSpec.describe MoneyGone::TransferDetector do
  it "marks high-score opposite transactions as transfers" do
    txs = [
      { id: "a1", bank_id: "a", booking_date: "2026-05-01", amount_signed: -100.0, description_clean: "bonifico" },
      { id: "b1", bank_id: "b", booking_date: "2026-05-01", amount_signed: 100.0, description_clean: "bonifico" }
    ]
    out = described_class.new.detect(txs)
    expect(out.find { |t| t[:id] == "a1" }[:excluded_from_spending]).to be(true)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/money_gone/transfer_detector_spec.rb -fd`  
Expected: FAIL due to missing detector.

- [ ] **Step 3: Write minimal implementation**

```ruby
# lib/money_gone/transfer_detector.rb
module MoneyGone
  class TransferDetector
    def detect(transactions)
      pairs = transactions.combination(2).select do |a, b|
        a[:bank_id] != b[:bank_id] && (a[:amount_signed] + b[:amount_signed]).abs < 0.01
      end
      pairs.each_with_index do |(a, b), idx|
        gid = "tg#{idx + 1}"
        a[:excluded_from_spending] = true
        b[:excluded_from_spending] = true
        a[:excluded_reason] = b[:excluded_reason] = "internal_transfer"
        a[:transfer_group_id] = b[:transfer_group_id] = gid
      end
      transactions
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/money_gone/transfer_detector_spec.rb -fd`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/money_gone/transfer_detector.rb spec/money_gone/transfer_detector_spec.rb
git commit -m "feat: add deterministic transfer detector"
```

### Task 6: Implement Categorizer with Fixed Categories + Suggestions

**Files:**
- Create: `lib/money_gone/categorizer.rb`
- Test: `spec/money_gone/categorizer_spec.rb`

- [ ] **Step 1: Write failing tests**

```ruby
RSpec.describe MoneyGone::Categorizer do
  it "assigns Altro when llm category is not allowed" do
    tx = { description_clean: "misterioso addebito" }
    fake_llm = double("llm", categorize: { "category" => "Crypto", "confidence" => 0.9, "suggested_new_category" => "Crypto" })
    out = described_class.new(categories: ["Spesa", "Altro"], llm_client: fake_llm).categorize([tx]).first
    expect(out[:category]).to eq("Altro")
    expect(out[:suggested_new_category]).to eq("Crypto")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/money_gone/categorizer_spec.rb -fd`  
Expected: FAIL due to missing categorizer.

- [ ] **Step 3: Write minimal implementation**

```ruby
# lib/money_gone/categorizer.rb
module MoneyGone
  class Categorizer
    def initialize(categories:, llm_client:, confidence_threshold: 0.65)
      @categories = categories
      @llm = llm_client
      @confidence_threshold = confidence_threshold
    end

    def categorize(transactions)
      transactions.map do |tx|
        next tx if tx[:excluded_from_spending]
        decision = @llm.categorize(tx)
        category = decision["category"]
        category = "Altro" unless @categories.include?(category)
        category = "Altro" if decision["confidence"].to_f < @confidence_threshold
        tx.merge(category: category, suggested_new_category: decision["suggested_new_category"])
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/money_gone/categorizer_spec.rb -fd`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/money_gone/categorizer.rb spec/money_gone/categorizer_spec.rb
git commit -m "feat: add categorizer with fixed-category guardrails"
```

### Task 7: Build Pipeline + Reporter + Analyze Command

**Files:**
- Create: `lib/money_gone/pipeline.rb`, `lib/money_gone/reporter.rb`
- Modify: `lib/money_gone/cli.rb`
- Test: `spec/money_gone/pipeline_integration_spec.rb`

- [ ] **Step 1: Write failing integration test**

```ruby
RSpec.describe "analyze integration" do
  it "prints category totals and transfer section" do
    out = `ruby bin/money-gone analyze --bank a:spec/fixtures/bank_a.csv --bank b:spec/fixtures/bank_b.xlsx`
    expect(out).to include("Totali per categoria")
    expect(out).to include("Giroconti riconosciuti")
    expect(out).to include("Nuove categorie suggerite")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/money_gone/pipeline_integration_spec.rb -fd`  
Expected: FAIL because pipeline and reporter are missing.

- [ ] **Step 3: Write minimal implementation**

```ruby
# lib/money_gone/reporter.rb
module MoneyGone
  class Reporter
    def render(result)
      puts "Totali per categoria"
      result[:totals].each { |k, v| puts "- #{k}: #{format('%.2f', v)}" }
      puts "\nGiroconti riconosciuti"
      result[:transfers].each { |t| puts "- #{t[:id]} (#{t[:amount_signed]})" }
      puts "\nNuove categorie suggerite"
      result[:suggestions].each { |k, v| puts "- #{k}: #{v}" }
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/money_gone/pipeline_integration_spec.rb -fd`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/money_gone/pipeline.rb lib/money_gone/reporter.rb lib/money_gone/cli.rb spec/money_gone/pipeline_integration_spec.rb spec/fixtures/bank_a.csv spec/fixtures/bank_b.xlsx
git commit -m "feat: wire full analyze pipeline and terminal reporting"
```

### Task 8: Harden Error Handling + Exit Codes

**Files:**
- Modify: `lib/money_gone/cli.rb`, `lib/money_gone/llm_client.rb`, `lib/money_gone/schema_mapper.rb`
- Test: `spec/money_gone/cli_errors_spec.rb`

- [ ] **Step 1: Write failing tests for error conditions**

```ruby
RSpec.describe "cli errors" do
  it "fails with non-zero when lm studio is unreachable" do
    out = `ruby bin/money-gone analyze --bank a:spec/fixtures/bank_a.csv 2>&1`
    expect($?.exitstatus).not_to eq(0)
    expect(out).to include("LM Studio unavailable")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec rspec spec/money_gone/cli_errors_spec.rb -fd`  
Expected: FAIL because current CLI does not map runtime errors to exit codes.

- [ ] **Step 3: Write minimal implementation**

```ruby
# in lib/money_gone/cli.rb
def analyze
  # ...
rescue MoneyGone::LlmClient::UnavailableError => e
  warn "LM Studio unavailable: #{e.message}"
  exit 2
rescue MoneyGone::SchemaMapper::MappingError => e
  warn "Schema mapping error: #{e.message}"
  exit 3
rescue StandardError => e
  warn "Unexpected error: #{e.message}"
  exit 1
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec rspec spec/money_gone/cli_errors_spec.rb -fd`  
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/money_gone/cli.rb lib/money_gone/llm_client.rb lib/money_gone/schema_mapper.rb spec/money_gone/cli_errors_spec.rb
git commit -m "fix: add robust cli error handling and exit codes"
```

### Task 9: Final Verification and Developer UX

**Files:**
- Modify: `README.md` (create if missing)
- Test: all specs

- [ ] **Step 1: Write README usage section**

```markdown
## Usage

1. Start LM Studio and expose OpenAI-compatible API.
2. Configure `config/lmstudio.yml`.
3. Run:
   `bundle exec ruby bin/money-gone analyze --bank a:path.csv --bank b:path.xlsx`
```

- [ ] **Step 2: Run full test suite**

Run: `bundle exec rspec -fd`  
Expected: all tests PASS.

- [ ] **Step 3: Run smoke command**

Run: `bundle exec ruby bin/money-gone --help`  
Expected: help output includes `analyze`.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: add setup and usage instructions"
```

