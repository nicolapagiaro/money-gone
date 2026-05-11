# Money Gone

Ruby CLI for normalizing multi-bank statements and building terminal reports (see `docs/superpowers/specs/`).

## Requirements

- Ruby 3.3+
- [Bundled gems](Gemfile), including `thor`, `csv`, `roo`
- [LM Studio](https://lmstudio.ai/) (for real categorization and `chat`)

## Setup

```bash
bundle install
```

## LM Studio

1. Avvia LM Studio e carica un modello (es. **Qwen 3.2 8B**).
2. Avvia il server locale e l’API **OpenAI-compatible** (di solito porta `1234`).
3. Adatta `config/lmstudio.yml` se servono altri host, porta o nome modello:

   - `base_url`: es. `http://127.0.0.1:1234/v1`
   - `model`: deve coincidere con l’id del modello servito da LM Studio (come compar nell’elenco modelli).
   - `timeout_s`: timeout HTTP in secondi.

## Usage

### Analisi estratti (con categorizzazione via LM)

Senza `--stub`, ogni movimento non escluso (es. non giroconto) viene inviato a LM Studio per ottenere categoria, confidenza e eventuale categoria suggerita.

```bash
bundle exec ruby bin/money-gone analyze banca1:path/to/a.csv banca2:path/to/b.xlsx
```

Override da riga di comando:

```bash
bundle exec ruby bin/money-gone analyze --lmstudio-url http://127.0.0.1:1234/v1 --model "nome-modello-esatto" a:estratti/uno.csv
```

Modalità **offline** (nessuna chiamata HTTP, categorie fisse di test):

```bash
bundle exec ruby bin/money-gone analyze --stub a:spec/fixtures/bank_a.csv b:spec/fixtures/bank_b.xlsx
```

Esempio con le fixture del repo:

```bash
bundle exec ruby bin/money-gone analyze --stub a:spec/fixtures/bank_a.csv b:spec/fixtures/bank_b.xlsx
```

### Chat con il modello locale

Sessione interattiva su `/v1/chat/completions` (stesso `base_url` e `model` della config, oppure override con le stesse opzioni di `analyze`):

```bash
bundle exec ruby bin/money-gone chat
```

Fine sessione: `exit`, `quit`, oppure Ctrl+C.

```bash
bundle exec ruby bin/money-gone chat --lmstudio-url http://127.0.0.1:1234/v1
```

## Configurazione categorie

Le categorie ammesse per il modello sono in `config/categories.yml`: sono pensate per coprire spese italiane tipiche (es. **Utenze**, **Supermercato e alimentari**, **Mangiare fuori**, **Svago**, …). Puoi editare l’elenco liberamente.

- Il modello deve usare la **stessa stringa** di una delle voci (l’app accetta anche differenze di **maiuscole/minuscole**).
- La soglia di confidenza sotto cui forziamo **Altro** è in `config/rules.yml` → `categorization.confidence_threshold` (predefinito ~0.42). Se vedi troppi «Altro», abbassala leggermente o verifica che LM risponda con `confidence` numerico; se `confidence` manca, l’app assume **0.75**.
- **`suggested_new_category`**: nel prompt chiediamo esplicitamente di riempirlo quando serve un’etichetta più specifica o quando la vera categoria manca dalla lista.

## Tests

```bash
bundle exec rspec -fd
```

Gli integration test usano `--stub` così non serve LM Studio in CI.

## Exit codes

- `0` success
- `1` unexpected error
- `2` LM Studio unavailable (connessione / server spento)
- `3` schema / column mapping error
- `4` LM Studio response error (HTTP o JSON non valido dal modello)

Ambiente di test: `MONEY_GONE_LLM_FAIL=1` simula indisponibilità LM durante `analyze`.
