#!/usr/bin/env bash
# ask-qwen.sh - delega un task di codice a Qwen3-Coder via LiteLLM (locale)
#
# Uso:
#   ./scripts/ask-qwen.sh "Scrivi una funzione Python che calcola il fattoriale"
#   echo "istruzioni lunghe" | ./scripts/ask-qwen.sh
#
# Requisiti: llama-server nativo Windows acceso su :8084 (alias local-code),
# LiteLLM su :4000 (docker compose up -d litellm).

set -euo pipefail

LITELLM_URL="${LITELLM_URL:-http://localhost:4000}"
MODEL="${QWEN_MODEL:-local-code}"
TIMEOUT="${QWEN_TIMEOUT:-120}"

if [[ -t 0 && $# -eq 0 ]]; then
  echo "Uso: $0 \"prompt\"   oppure   echo prompt | $0" >&2
  exit 1
fi

if [[ $# -gt 0 ]]; then
  PROMPT="$*"
else
  PROMPT="$(cat)"
fi

PAYLOAD=$(python3 -c '
import json, sys
print(json.dumps({"model": sys.argv[2], "messages": [{"role": "user", "content": sys.argv[1]}]}))
' "$PROMPT" "$MODEL")

RESPONSE=$(curl -s --max-time "$TIMEOUT" \
  -X POST "$LITELLM_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD") || {
  echo "Errore: impossibile contattare LiteLLM su $LITELLM_URL" >&2
  echo "Verifica: docker compose ps, e che llama-server giri su :8084" >&2
  exit 1
}

python3 -c '
import json, sys
data = json.loads(sys.argv[1])
if "error" in data:
    print("Errore da LiteLLM:", data["error"].get("message", data["error"]), file=sys.stderr)
    sys.exit(1)
print(data["choices"][0]["message"]["content"])
' "$RESPONSE"
