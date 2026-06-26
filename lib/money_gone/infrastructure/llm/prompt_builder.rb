# frozen_string_literal: true

module MoneyGone
  module Infrastructure
    module Llm
      class PromptBuilder
        FAST_SYSTEM_PROMPT = <<~PROMPT
          Sei un assistente che classifica movimenti bancari italiani in una di poche categorie di spesa/risparmio fisse.

          Leggi data, importo (negativo = uscita dal conto) e descrizione; scegli l'etichetta più adatta tra quelle ammesse.
          Se nessuna categoria calza bene, usa "Altro" solo se compare nell'elenco sotto.

          Rispondi SOLO con questo JSON valido, senza testo prima o dopo e senza markdown:
          {"category":"...","confidence":0.xx}

          Regole:
          - "category": copia ESATTAMENTE una di queste etichette: %<categories_line>s
            (unica eccezione: puoi ignorare solo maiuscole/minuscole).
          - "confidence": numero tra 0 e 1 (quanto sei sicuro).
          - Non aggiungere altri campi, spiegazioni o ragionamento visibile.
        PROMPT

        FULL_SYSTEM_PROMPT = <<~PROMPT
          Sei un assistente per classificare movimenti bancari in italiano.

          Rispondi SOLO con un unico oggetto JSON valido (nessun testo fuori dal JSON, niente markdown).

          Campi obbligatori:
          - "category": stringa identica a UNA delle etichette elencate dall'utente sotto "Categorie ammesse".
            Copia l'etichetta esattamente come scritta (stesse parole, punteggiatura; puoi ignorare solo differenze di maiuscole/minuscole).
          - "confidence": numero tra 0 e 1 (quanto sei sicuro della scelta).
          - "rationale_short": una frase breve in italiano che spiega perché.
          - "suggested_new_category": stringa o null.
            Usalo in due casi: (1) la categoria corretta non c'è nell'elenco — scegli la più simile in "category" e qui proponi il nome più utile;
            (2) anche se la categoria scelta va bene, puoi proporre un nome più specifico per il futuro (es. "Discount" vs supermercato generico).

          Se il movimento non è una spesa/uso chiaro, usa "Altro" solo se presente tra le ammesse.
        PROMPT

        FULL_SCHEMA_PROPERTIES = {
          category: { type: 'string' },
          confidence: { type: 'number' },
          rationale_short: { type: %w[string null] },
          suggested_new_category: { type: %w[string null] }
        }.freeze

        def categorization_schema_fast
          {
            type: 'object',
            properties: {
              category: { type: 'string' },
              confidence: { type: 'number' }
            },
            required: %w[category confidence],
            additionalProperties: false
          }
        end

        def categorization_schema_full
          {
            type: 'object',
            properties: FULL_SCHEMA_PROPERTIES,
            required: %w[category confidence rationale_short suggested_new_category],
            additionalProperties: false
          }
        end

        def categorization_bundle(user, categories_line, include_suggestions:)
          if include_suggestions
            full_categorization_bundle(user, categories_line)
          else
            fast_categorization_bundle(user, categories_line)
          end
        end

        def fast_categorization_bundle(user, categories_line)
          [system_prompt_fast(categories_line), user_block_fast(user, categories_line), 0.2, categorization_schema_fast]
        end

        def full_categorization_bundle(user, categories_line)
          [system_prompt_full(categories_line), user_block_full(user, categories_line), 0.28, categorization_schema_full]
        end

        def system_prompt_fast(categories_line)
          format(FAST_SYSTEM_PROMPT, categories_line: categories_line).strip
        end

        def user_block_fast(user, categories_line)
          <<~USER.strip
            Etichette ammesse: #{categories_line}

            Movimento da classificare:
            #{user}
          USER
        end

        def system_prompt_full(_categories_line)
          FULL_SYSTEM_PROMPT.strip
        end

        def user_block_full(user, categories_line)
          <<~USER.strip
            Categorie ammesse: #{categories_line}

            Movimento da classificare:
            #{user}
          USER
        end

        def format_transaction_for_prompt(row)
          <<~TXT.strip
            id: #{row[:id]}
            banca: #{row[:bank_id]}
            data: #{row[:booking_date]}
            importo (segno contabile, negativo = uscita): #{row[:amount_signed]}
            descrizione: #{row[:description_clean] || row[:description_raw]}
          TXT
        end
      end
    end
  end
end
