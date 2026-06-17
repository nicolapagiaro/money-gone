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
Eccezione: se `config/rules.yml` contiene una regola in `categorization.description_category_includes` che matcha la descrizione, la categoria viene assegnata in modo deterministico e quel movimento non viene inviato all'LLM.

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
- **Regole includes prima dell'LLM**: in `config/rules.yml` puoi impostare:

```yml
categorization:
  description_category_includes:
    "esselunga": "Supermercato e alimentari"
    "telepass": "Auto e trasporti"
```

La chiave viene cercata come sottostringa nella descrizione (match case-insensitive, senza accenti). Al primo match valido, la categoria viene assegnata e il movimento viene escluso dalla richiesta LLM.

## Tests

```bash
bundle exec rspec -fd
```

Gli integration test usano `--stub` così non serve LM Studio in CI.

## Detection giroconti (stessa banca e banche diverse)

La pipeline esclude dai totali di spesa i movimenti identificati come giroconto (`excluded_from_spending: true`), così non falsano `entrate`, `uscite` e `netto`.

La detection e` volutamente semplice: ogni movimento viene marcato come giroconto solo se la sua `description_raw` matcha regole statiche configurate.

Regole disponibili:

- `description_raw_keywords`: match parziale (case-insensitive), ad esempio se la descrizione contiene `"conto deposito"`.
- `description_raw_exact`: match esatto (case-insensitive), utile per descrizioni standard della banca.

Non vengono usati:

- tolleranza su importo
- differenza giorni tra movimenti
- sistema di score/confidenza

### Configurazione (`config/rules.yml`)

```yml
transfer:
  enabled: true
  description_raw_keywords:
    - "conto deposito"
    - "giroconto"
    - "trasferimento interno"
    - "versamento su conto deposito"
    - "versamento da conto deposito"
  description_raw_exact: []
```

Note pratiche:

- aggiungi keyword specifiche della tua banca in `description_raw_keywords`;
- usa `description_raw_exact` quando vuoi regole molto strette;
- i movimenti esclusi vengono marcati con `excluded_reason: internal_transfer_by_description`.

## Exit codes

- `0` success
- `1` unexpected error
- `2` LM Studio unavailable (connessione / server spento)
- `3` schema / column mapping error
- `4` LM Studio response error (HTTP o JSON non valido dal modello)

Ambiente di test: `MONEY_GONE_LLM_FAIL=1` simula indisponibilità LM durante `analyze`.
