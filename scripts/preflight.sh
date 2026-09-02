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

for name in homelab-ai-llama homelab-ai-litellm homelab-ai-searxng homelab-ai-sandbox \
            homelab-ai-postgres homelab-ai-qdrant; do
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

  # Hardware probe for the amd branch.
  # Closes the gap listed in docs/amd-migration.md ("Known gaps"): preflight amd
  # had no real hardware check equivalent to the nvidia-smi probe.
  #
  # Which probe is correct depends on the runtime actually in use, exactly as
  # that document warns. compose.amd.yml pins the Vulkan server image, so
  # vulkan is the default; set AMD_RUNTIME=rocm in .env to probe ROCm instead.
  amd_runtime="${AMD_RUNTIME:-vulkan}"
  expected_gfx="${AMD_EXPECTED_GFX:-gfx1151}"

  case "$amd_runtime" in
    vulkan)
      if ! command -v vulkaninfo >/dev/null 2>&1; then
        fail "vulkaninfo not found in WSL (apt install vulkan-tools); cannot confirm the GPU is visible"
        errors=$((errors+1))
      else
        gpu_line="$(vulkaninfo --summary 2>/dev/null | grep -i 'deviceName' | head -n1 || true)"
        if [[ -z "$gpu_line" ]]; then
          fail "vulkaninfo reports no Vulkan device inside WSL"
          errors=$((errors+1))
        elif grep -qi 'llvmpipe' <<< "$gpu_line"; then
          # llvmpipe is Mesa's software rasteriser. If it is the reported device
          # there is no GPU acceleration at all, and llama-server will run on CPU
          # WITHOUT reporting an error. Catching that here is the whole point of
          # this probe: the alternative is discovering it in a benchmark.
          fail "Vulkan is falling back to llvmpipe (software rendering) - this is the silent CPU path"
          errors=$((errors+1))
        elif ! grep -qiE 'radeon|amd' <<< "$gpu_line"; then
          fail "Vulkan device is not an AMD GPU: $gpu_line"
          errors=$((errors+1))
        else
          echo "GPU (vulkan): $(sed 's/.*= *//' <<< "$gpu_line")"
        fi
      fi
      ;;
    rocm)
      if ! command -v rocminfo >/dev/null 2>&1; then
        fail "rocminfo not found in WSL; ROCm runtime is not installed"
        errors=$((errors+1))
      else
        gfx="$(rocminfo 2>/dev/null | grep -oE 'gfx[0-9a-f]+' | sort -u | tr '\n' ' ' || true)"
        if [[ -z "$gfx" ]]; then
          fail "rocminfo found no GPU agent"
          errors=$((errors+1))
        else
          echo "GPU (rocm): $gfx"
          if ! grep -q "$expected_gfx" <<< "$gfx"; then
            echo "WARN: expected $expected_gfx (Strix Halo), rocminfo reports: $gfx"
          fi
        fi
      fi
      ;;
    *)
      fail "unknown AMD_RUNTIME '$amd_runtime' (expected: vulkan or rocm)"
      errors=$((errors+1))
      ;;
  esac
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
