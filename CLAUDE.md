## Delega a Qwen-Coder locale
Per generazione di codice ripetitiva, boilerplate, o funzioni ben definite,
usa `./scripts/ask-qwen.sh "<istruzione>"` invece di scriverle direttamente —
gira su Qwen3-Coder-30B locale via LiteLLM, riduce l'uso di token Claude.
Rivedi sempre l'output prima di integrarlo: è un modello più piccolo, può
sbagliare edge case.

## Stato attuale (3 settembre 2026 — aggiornato)
- Stack Docker: 10/10 smoke test passano (llama, litellm, postgres, qdrant, sandbox, searxng)
- Qwen3-Coder-30B nativo Windows su porta 8084, alias `local-code` in LiteLLM
- Schema Postgres (`db/schema.sql`, tabelle `sources`+`chunks`) applicato e
  verificato con `\dt` — era stato perso una volta in sessione (dati su disco
  ma schema non caricato), riapplicato senza perdita di dati grazie a
  ingestion idempotente su sha256
- `scripts/ingest.py`: supporto .txt/.md completo + supporto PDF con soglia
  qualità OCR, eseguito in servizio Docker dedicato sulla rete `homelab-ai-net`
  (Postgres non ha porta esposta all'host, per scelta di sicurezza)
- Ingeriti i 4 PDF portfolio "Overtake Crew" (F1 in Schools, ITIS Leonardo da
  Vinci) in `data/ingestion-input/`: project management, enterprise,
  engineering, + portfolio generale. Source_id verificati in Postgres.
- I PDF di Analisi 1 (del fratello dell'utente) sono stati rimossi da
  `sources` — non più presenti nel DB
- Golden dataset: **fatto**, 21 voci (5 domande per ciascuno dei 4 PDF
  Overtake Crew + 2 domande "trappola"), validato strutturalmente con
  `scripts/validate_golden_dataset.py` (0 errori). File reale tenuto FUORI
  dal repo pubblico via `.gitignore` (contiene dati sensibili: importi
  sponsor, metriche social) — vive solo in locale in
  `data/golden-dataset/golden_dataset.yaml`
- Prossimo: rag-eval-harness (Fase 4, non ancora costruito) per confrontare
  automaticamente le risposte del RAG contro il golden dataset

## Ambiente di esecuzione (importante, non re-investigare)
- Il Bash tool di Claude Code è Git Bash/MSYS (python3 non reale, solo lo
  stub Store). Da un terminale WSL separato, python3 è reale.
  `ask-qwen.sh` fa auto-detect per gestire entrambi i casi.
