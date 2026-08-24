#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
command -v docker >/dev/null 2>&1 || { echo "FAIL: docker CLI missing" >&2; exit 1; }
docker info >/dev/null 2>&1 || { echo "FAIL: Docker daemon unreachable" >&2; exit 1; }

image_tar="${1:-}"
if [[ -z "$image_tar" && -f "$PROJECT_DIR/../images/homelab-ai-images.tar" ]]; then
  image_tar="$PROJECT_DIR/../images/homelab-ai-images.tar"
fi
if [[ -n "$image_tar" ]]; then
  [[ -f "$image_tar" ]] || { echo "FAIL: image archive not found: $image_tar" >&2; exit 1; }
  if [[ -f "$image_tar.sha256" ]]; then
    (cd "$(dirname "$image_tar")" && sha256sum -c "$(basename "$image_tar").sha256")
  fi
  docker load -i "$image_tar"
  echo "PASS: Docker images loaded"
else
  echo "INFO: no images archive supplied; pinned images can be pulled later."
fi

if [[ ! -f "$PROJECT_DIR/.env" ]]; then
  "$SCRIPT_DIR/setup.sh"
fi
cat <<'TXT'
Import preparation complete.
Do NOT start AMD inference yet.
Next on the future AMD PC:
  1. Read docs/amd-migration.md
  2. Validate WSL2 + AMD driver + Vulkan/ROCm visibility
  3. Only then enable ALLOW_UNVALIDATED_AMD=1 in .env
  4. Run ./scripts/preflight.sh amd
  5. Run ./scripts/build.sh amd (or use a validated imported AMD image)
  6. Run ./scripts/start.sh amd
  7. Run ./scripts/test.sh amd
TXT
