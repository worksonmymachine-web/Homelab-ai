
## Delega a Qwen-Coder locale

Per generazione di codice ripetitiva, boilerplate, o funzioni ben definite,
usa `./scripts/ask-qwen.sh "<istruzione>"` invece di scriverle direttamente —
gira su Qwen3-Coder-30B locale via LiteLLM, riduce l'uso di token Claude.
Rivedi sempre l'output prima di integrarlo: è un modello più piccolo, può
sbagliare edge case.

## Stato attuale (3 settembre 2026)

- Stack Docker: 10/10 smoke test passano (llama, litellm, postgres, qdrant, sandbox, searxng)
- Qwen3-Coder-30B nativo Windows su porta 8084, alias `local-code` in LiteLLM
- Schema Postgres per ingestion (`db/schema.sql`) da scrivere: tabelle `sources`
  e `chunks`, vedi checkpoint per i campi esatti
- Prossimo task: script `scripts/ingest.py` per ingestion .txt/.md/PDF verso Postgres,
  eseguito in un servizio Docker dedicato sulla rete `homelab-ai-net`
  (Postgres non ha porta esposta all'host, per scelta di sicurezza)
- Golden dataset: si riparte da zero (v0.2 precedente abbandonato volutamente)
