#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="homelab-ai"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

load_env() {
  if [[ -f "$PROJECT_DIR/.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$PROJECT_DIR/.env"
    set +a
  fi
}

compose_files() {
  local backend="${1:-nvidia}"
  case "$backend" in
    nvidia) printf '%s\n' "-f" "$PROJECT_DIR/compose.yml" "-f" "$PROJECT_DIR/compose.nvidia.yml" ;;
    amd) printf '%s\n' "-f" "$PROJECT_DIR/compose.yml" "-f" "$PROJECT_DIR/compose.amd.yml" ;;
    cpu) printf '%s\n' "-f" "$PROJECT_DIR/compose.yml" ;;
    *) echo "Unknown backend: $backend" >&2; return 2 ;;
  esac
}

compose() {
  local backend="${1:-nvidia}"
  shift || true
  local files=()
  mapfile -t files < <(compose_files "$backend")
  docker compose -p "$PROJECT_NAME" "${files[@]}" "$@"
}

require_docker() {
  command -v docker >/dev/null 2>&1 || { echo "FAIL: docker CLI not found" >&2; exit 1; }
  docker info >/dev/null 2>&1 || { echo "FAIL: cannot reach Docker daemon" >&2; exit 1; }
  docker compose version >/dev/null 2>&1 || { echo "FAIL: Docker Compose unavailable" >&2; exit 1; }
}

is_our_container() {
  local name="$1" project
  project="$(docker inspect -f '{{ index .Config.Labels "com.docker.compose.project" }}' "$name" 2>/dev/null || true)"
  [[ "$project" == "$PROJECT_NAME" ]]
}

pass() { printf 'PASS: %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; }
