#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"
load_env

url="${MODEL_URL:-https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf?download=true}"
file="${MODEL_FILE:-qwen2.5-1.5b-instruct-q4_k_m.gguf}"
approx="${MODEL_APPROX_BYTES:-1200000000}"
target="$PROJECT_DIR/models/$file"

echo "Model: Qwen2.5-1.5B-Instruct GGUF Q4_K_M"
echo "Target: $target"
echo "Approx download: ~1.12 GiB (configured safety estimate: $approx bytes)"
echo "License: Apache-2.0 (see upstream model card)"

free="$(df -PB1 "$PROJECT_DIR/models" | awk 'NR==2 {print $4}')"
echo "Free disk: $((free/1024/1024/1024)) GiB"
if (( free < approx * 2 )); then
  echo "FAIL: need at least roughly 2x model size free for safe download." >&2
  exit 1
fi

if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=name,memory.total --format=csv,noheader | head -n1 | sed 's/^/GPU: /'
fi

if [[ -f "$target" ]]; then
  echo "Model already exists; not downloading again."
  sha256sum "$target" | tee "$target.sha256"
  exit 0
fi

if [[ "${1:-}" != "--yes" ]]; then
  read -r -p "Download this single smoke-test model? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || { echo "Cancelled; nothing downloaded."; exit 0; }
fi

partial="$target.partial"
rm -f "$partial"
curl -fL --retry 3 --retry-delay 2 --progress-bar "$url" -o "$partial"
mv "$partial" "$target"
sha256sum "$target" | tee "$target.sha256"
echo "PASS: model downloaded outside Docker images."
