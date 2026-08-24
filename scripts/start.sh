#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"
load_env
backend="${1:-nvidia}"
"$SCRIPT_DIR/preflight.sh" "$backend"

model="$PROJECT_DIR/models/${MODEL_FILE:-qwen2.5-1.5b-instruct-q4_k_m.gguf}"
if [[ ! -f "$model" ]]; then
  fail "model not found: $model"
  echo "Run: ./scripts/download-model.sh"
  exit 1
fi

compose "$backend" up -d --no-build
pass "containers started for backend $backend"
echo "Next: ./scripts/test.sh $backend"
