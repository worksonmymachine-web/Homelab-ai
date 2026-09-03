#!/usr/bin/env bash
# ask-qwen.sh - delega un task di codice a Qwen3-Coder via LiteLLM (locale)
#
# Uso:
#   ./scripts/ask-qwen.sh "Scrivi una funzione Python che calcola il fattoriale"
#   echo "istruzioni lunghe" | ./scripts/ask-qwen.sh
#
# Requisiti: llama-server nativo Windows acceso su :8084 (alias local-code),
# LiteLLM su :4000 (docker compose up -d litellm).
#
# Usa node per costruire/parsare il JSON (non python3): su Git Bash (Windows)
# python3 e' spesso solo lo stub di Microsoft Store, mentre node e' disponibile
# sia li' che sotto WSL.

set -euo pipefail

LITELLM_URL="${LITELLM_URL:-http://localhost:4000}"
MODEL="${QWEN_MODEL:-local-code}"
TIMEOUT="${QWEN_TIMEOUT:-120}"

if ! command -v node >/dev/null 2>&1; then
  echo "Errore: node non trovato nel PATH (richiesto per costruire/parsare il JSON)." >&2
  exit 1
fi

if [[ -t 0 && $# -eq 0 ]]; then
  echo "Uso: $0 \"prompt\"   oppure   echo prompt | $0" >&2
  exit 1
fi

if [[ $# -gt 0 ]]; then
  PROMPT="$*"
else
  PROMPT="$(cat)"
fi

PAYLOAD=$(node -e '
const [prompt, model] = process.argv.slice(1);
process.stdout.write(JSON.stringify({ model, messages: [{ role: "user", content: prompt }] }));
' "$PROMPT" "$MODEL")

RESPONSE=$(curl -s --max-time "$TIMEOUT" \
  -X POST "$LITELLM_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD") || {
  echo "Errore: impossibile contattare LiteLLM su $LITELLM_URL" >&2
  echo "Verifica: docker compose ps, e che llama-server giri su :8084" >&2
  exit 1
}

node -e '
const data = JSON.parse(process.argv[1]);
if (data.error) {
  console.error("Errore da LiteLLM:", data.error.message || data.error);
  process.exit(1);
}
process.stdout.write(data.choices[0].message.content);
' "$RESPONSE"
