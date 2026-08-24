#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"
load_env
backend="${1:-nvidia}"
"$SCRIPT_DIR/preflight.sh" "$backend"

if [[ "$backend" == "amd" && "${ALLOW_UNVALIDATED_AMD:-0}" != "1" ]]; then
  fail "AMD build blocked until migration prerequisites are validated"
  exit 1
fi

echo "Pulling pinned service images for backend: $backend"
compose "$backend" pull llama litellm searxng

echo "Building only project-owned sandbox image"
compose "$backend" build sandbox
pass "build completed"
