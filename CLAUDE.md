
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

## Ambiente di esecuzione (importante, non re-investigare)

- `bash` su questa macchina è lo stub WSL (`C:\Windows\System32\bash.exe`):
  ogni script .sh lanciato da Claude Code gira DENTRO WSL, non su Windows nativo.
- python3 esiste in WSL, NON su PowerShell/Windows nativo. Non serve installare
  python su Windows: gli script bash lo trovano già in WSL.
- `./scripts/ask-qwen.sh` funziona così com'è, verificato il 3 settembre 2026.
  Se sembra fallire, il problema è altrove (LiteLLM/llama-server spenti), non
  python3 mancante.
