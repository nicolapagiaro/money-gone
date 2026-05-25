# Money Gone

Ruby CLI for normalizing multi-bank statements and building terminal reports (see `docs/superpowers/specs/`).

## Requirements

- Ruby 3.3+
- [Bundled gems](Gemfile), including `thor`, `csv`, `roo`, `pdf-reader`, `rtesseract`
- [LM Studio](https://lmstudio.ai/) (per categorizzazione reale, parsing dei PDF e `chat`)

Per gli estratti **solo immagine** (PDF scannerizzati), servono anche tool di sistema oltre alle gem:

- **Tesseract** con i pacchetti lingua che userai (es. italiano + inglese).
- Un modo per convertire le pagine PDF in immagini: **Poppler** (`pdftoppm`, es. `brew install poppler`) oppure **ImageMagick + Ghostscript** (`magick` o `convert`).

La lingua OCR è configurabile con la variabile d’ambiente `MONEY_GONE_OCR_LANG` (predefinito `ita+eng`, sintassi Tesseract).

Il testo inviato a LM Studio per **estrarre i movimenti dal PDF** viene spezzato in più richieste se è lungo. Il tetto in byte per chunk è configurabile (valori bassi, es. 3000–4000, aiutano con contesti ~**4096 token**):

- `config/rules.yml` → `statement_pdf.max_chunk_bytes`
- oppure variabile d’ambiente `MONEY_GONE_STATEMENT_CHUNK_BYTES` (ha priorità sul valore in YAML)

Per **ispezionare** il testo estratto (PDF nativo o OCR) **prima** delle chiamate LLM, è attivo il salvataggio in `tmp/money-gone-pdf-extract/` sotto la root del progetto (`tmp/` non è versionato). Si controlla con `statement_pdf.dump_extracted_text` in `rules.yml` oppure con `MONEY_GONE_DUMP_PDF_TEXT` (`1` / `true` / `yes` / `on` per forzare l’attivazione, `0` / `false` / `no` / `off` per disabilitare anche se nel YAML è true).

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

Formati supportati per il path dell’estratto: **`.csv`**, **`.xlsx` / `.xls`**, **`.pdf`**.

I CSV e gli Excel vengono letti in modo deterministico. I PDF passano da estrazione testo (se il PDF contiene testo selezionabile) o da OCR; il testo viene poi mandato a LM Studio per ricavare un elenco di movimenti in JSON (stesso modello usato per la categorizzazione).

```bash
bundle exec ruby bin/money-gone analyze banca1:path/to/a.csv banca2:path/to/b.xlsx miaBanca:estratti/movimenti.pdf
```

Override da riga di comando:

```bash
bundle exec ruby bin/money-gone analyze --lmstudio-url http://127.0.0.1:1234/v1 --model "nome-modello-esatto" a:estratti/uno.csv
```

Modalità **offline** rispetto a LM Studio (nessuna chiamata HTTP); la categorizzazione e il parsing del testo estratto dal PDF usano risposte fisse di test.

```bash
bundle exec ruby bin/money-gone analyze --stub a:spec/fixtures/bank_a.csv b:spec/fixtures/bank_b.xlsx
```

Con un PDF reale, **testo incorporato e OCR restano attivi** per produrre il testo da “tradurre” in righe; sono bypassate solo le richieste al modello remoto (movimenti simulati o categorie stub).

Per provare un PDF in stub (richiede comunque un file PDF leggibile o toolchain OCR se è scannerizzato):

```bash
bundle exec ruby bin/money-gone analyze --stub mybank:/percorso/al/file.pdf
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
- `1` unexpected error (include alcuni errori generici su file PDF)
- `2` LM Studio unavailable (connessione / server spento)
- `3` schema / column mapping error (anche righe incomplete dal parsing PDF/LLM)
- `4` LM Studio response error (HTTP o JSON non valido dal modello)
- `5` PDF OCR non disponibile (manca Poppler/ImageMagick o la rasterizzazione delle pagine fallisce; messaggio con suggerimenti)

Ambiente di test: `MONEY_GONE_LLM_FAIL=1` simula indisponibilità LM durante `analyze`.
