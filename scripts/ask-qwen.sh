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
# Costruzione/parsing del JSON: usa python3 se disponibile e funzionante,
# altrimenti node. Su Git Bash (Windows) python3 e' spesso solo lo stub di
# Microsoft Store (presente nel PATH ma fallisce all'esecuzione), mentre da
# un terminale WSL vero python3 e' reale. node e' disponibile in entrambi.

set -euo pipefail

LITELLM_URL="${LITELLM_URL:-http://localhost:4000}"
MODEL="${QWEN_MODEL:-local-code}"
TIMEOUT="${QWEN_TIMEOUT:-120}"

JSON_TOOL=""
if command -v python3 >/dev/null 2>&1 && python3 -c "import sys" >/dev/null 2>&1; then
  JSON_TOOL="python3"
elif command -v node >/dev/null 2>&1; then
  JSON_TOOL="node"
else
  echo "Errore: serve python3 (funzionante) o node nel PATH per costruire/parsare il JSON." >&2
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

if [[ "$JSON_TOOL" == "python3" ]]; then
  PAYLOAD=$(python3 -c '
import json, sys
print(json.dumps({"model": sys.argv[2], "messages": [{"role": "user", "content": sys.argv[1]}]}))
' "$PROMPT" "$MODEL")
else
  PAYLOAD=$(node -e '
const [prompt, model] = process.argv.slice(1);
process.stdout.write(JSON.stringify({ model, messages: [{ role: "user", content: prompt }] }));
' "$PROMPT" "$MODEL")
fi

RESPONSE=$(curl -s --max-time "$TIMEOUT" \
  -X POST "$LITELLM_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD") || {
  echo "Errore: impossibile contattare LiteLLM su $LITELLM_URL" >&2
  echo "Verifica: docker compose ps, e che llama-server giri su :8084" >&2
  exit 1
}

if [[ "$JSON_TOOL" == "python3" ]]; then
  python3 -c '
import json, sys
data = json.loads(sys.argv[1])
if "error" in data:
    print("Errore da LiteLLM:", data["error"].get("message", data["error"]), file=sys.stderr)
    sys.exit(1)
print(data["choices"][0]["message"]["content"])
' "$RESPONSE"
else
  node -e '
const data = JSON.parse(process.argv[1]);
if (data.error) {
  console.error("Errore da LiteLLM:", data.error.message || data.error);
  process.exit(1);
}
process.stdout.write(data.choices[0].message.content);
' "$RESPONSE"
fi
