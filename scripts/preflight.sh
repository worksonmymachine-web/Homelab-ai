#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"
load_env
require_docker

backend="${1:-nvidia}"
errors=0

echo "== Homelab AI preflight ($backend) =="
echo "Project: $PROJECT_DIR"
echo "Docker: $(docker version --format '{{.Server.Version}}')"
echo "Compose: $(docker compose version --short)"

for name in homelab-ai-llama homelab-ai-litellm homelab-ai-searxng homelab-ai-sandbox; do
  if docker container inspect "$name" >/dev/null 2>&1; then
    if is_our_container "$name"; then
      echo "INFO: existing project container: $name"
    else
      fail "container name collision: $name exists but is not compose project homelab-ai"
      errors=$((errors+1))
    fi
  fi
done

if docker network inspect homelab-ai-net >/dev/null 2>&1; then
  label="$(docker network inspect -f '{{ index .Labels "io.homelab-ai.project" }}' homelab-ai-net 2>/dev/null || true)"
  if [[ "$label" == "homelab-ai" ]]; then
    echo "INFO: existing project network: homelab-ai-net"
  else
    fail "network name collision: homelab-ai-net exists without our project label"
    errors=$((errors+1))
  fi
fi

sandbox_image="${SANDBOX_IMAGE:-homelab-ai-sandbox:0.1.0}"
if docker image inspect "$sandbox_image" >/dev/null 2>&1; then
  label="$(docker image inspect -f '{{ index .Config.Labels "io.homelab-ai.project" }}' "$sandbox_image" 2>/dev/null || true)"
  if [[ "$label" != "homelab-ai" ]]; then
    fail "image tag collision: $sandbox_image exists without our project label"
    errors=$((errors+1))
  else
    echo "INFO: existing project image: $sandbox_image"
  fi
fi

check_port() {
  local port="$1" expected="$2"
  local owners
  owners="$(docker ps --filter "publish=$port" --format '{{.Names}}' 2>/dev/null || true)"
  if [[ -n "$owners" ]]; then
    while IFS= read -r owner; do
      [[ "$owner" == "$expected" ]] || { fail "host port $port is used by Docker container $owner"; errors=$((errors+1)); }
    done <<< "$owners"
  elif command -v ss >/dev/null 2>&1 && ss -ltnH | awk '{print $4}' | grep -Eq "(^|:)$port$"; then
    fail "host port $port is already listening outside our Docker container"
    errors=$((errors+1))
  fi
}
check_port "${LITELLM_PORT:-4000}" homelab-ai-litellm
check_port "${SEARXNG_PORT:-8888}" homelab-ai-searxng

free_kb="$(df -Pk "$PROJECT_DIR" | awk 'NR==2 {print $4}')"
echo "Free space: $((free_kb/1024/1024)) GiB"
if (( free_kb < 5*1024*1024 )); then
  fail "less than 5 GiB free in project filesystem"
  errors=$((errors+1))
fi

if [[ "$backend" == "nvidia" ]]; then
  if ! command -v nvidia-smi >/dev/null 2>&1; then
    fail "nvidia-smi not found in WSL"
    errors=$((errors+1))
  else
    echo "GPU: $(nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader | head -n1)"
  fi
elif [[ "$backend" == "amd" ]]; then
  if [[ "${ALLOW_UNVALIDATED_AMD:-0}" != "1" ]]; then
    fail "AMD backend is intentionally unvalidated; follow docs/amd-migration.md first"
    errors=$((errors+1))
  fi
fi

if [[ ! -f "$PROJECT_DIR/.env" ]]; then
  fail ".env missing; run ./scripts/setup.sh"
  errors=$((errors+1))
fi

if (( errors > 0 )); then
  echo "Preflight blocked startup: $errors issue(s). Nothing was changed."
  exit 1
fi
pass "preflight checks"
