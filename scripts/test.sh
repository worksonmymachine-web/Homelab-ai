#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"
load_env
backend="${1:-nvidia}"
failures=0

run_test() {
  local num="$1" name="$2"; shift 2
  printf '\nTEST %s - %s\n' "$num" "$name"
  if "$@"; then pass "$name"; else fail "$name"; failures=$((failures+1)); fi
}

container_running() { [[ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" == "true" ]]; }

wait_llama() {
  for _ in $(seq 1 90); do
    if docker exec homelab-ai-litellm python -c 'import urllib.request; r=urllib.request.urlopen("http://homelab-ai-llama:8080/health", timeout=3); raise SystemExit(0 if r.status==200 else 1)' >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  docker logs --tail 50 homelab-ai-llama >&2 || true
  return 1
}

t1() { container_running homelab-ai-llama && wait_llama; }
t2() { curl -fsS --max-time 10 "http://127.0.0.1:${LITELLM_PORT:-4000}/v1/models" >/dev/null; }
t3() {
  local out
  out="$(curl -fsS --max-time 120 "http://127.0.0.1:${LITELLM_PORT:-4000}/v1/chat/completions" \
    -H 'Content-Type: application/json' \
    -d "{\"model\":\"${LITELLM_MODEL_NAME:-local-qwen}\",\"messages\":[{\"role\":\"user\",\"content\":\"Reply with the word OK.\"}],\"max_tokens\":16,\"temperature\":0}" )" || return 1
  python3 -c 'import json,sys; d=json.load(sys.stdin); assert d.get("choices") and d["choices"][0].get("message",{}).get("content") is not None' <<<"$out"
}
t4() { curl -fsS --max-time 15 "http://127.0.0.1:${SEARXNG_PORT:-8888}/" >/dev/null; }
t5() {
  [[ "$(docker exec homelab-ai-sandbox id -u)" != "0" ]] || return 1
  [[ "$(docker exec homelab-ai-sandbox python3 -c 'print(6*7)')" == "42" ]] || return 1
  docker exec homelab-ai-sandbox sh -lc 'git --version >/dev/null && cmake --version >/dev/null && g++ --version >/dev/null'
}
t6() {
  docker exec homelab-ai-litellm python -c 'import urllib.request; assert urllib.request.urlopen("http://homelab-ai-llama:8080/health",timeout=5).status==200; assert urllib.request.urlopen("http://homelab-ai-searxng:8080/",timeout=5).status==200'
}
t7() {
  local user privileged network mounts caps sec
  user="$(docker inspect -f '{{.Config.User}}' homelab-ai-sandbox)"
  privileged="$(docker inspect -f '{{.HostConfig.Privileged}}' homelab-ai-sandbox)"
  network="$(docker inspect -f '{{.HostConfig.NetworkMode}}' homelab-ai-sandbox)"
  mounts="$(docker inspect -f '{{range .Mounts}}{{.Destination}} {{end}}' homelab-ai-sandbox)"
  caps="$(docker inspect -f '{{json .HostConfig.CapDrop}}' homelab-ai-sandbox)"
  sec="$(docker inspect -f '{{json .HostConfig.SecurityOpt}}' homelab-ai-sandbox)"
  [[ -n "$user" && "$user" != "0" && "$user" != "root" ]] || return 1
  [[ "$privileged" == "false" ]] || return 1
  [[ "$network" != "host" ]] || return 1
  [[ "$mounts" != *"/var/run/docker.sock"* ]] || return 1
  [[ "$caps" == *"ALL"* ]] || return 1
  [[ "$sec" == *"no-new-privileges"* ]] || return 1
}
t8() {
  local img llama_img
  case "$backend" in
    nvidia) llama_img="${LLAMA_NVIDIA_IMAGE:-ghcr.io/ggml-org/llama.cpp:server-cuda13-b10524}" ;;
    amd) llama_img="${LLAMA_AMD_IMAGE:-ghcr.io/ggml-org/llama.cpp:server-vulkan-b10524}" ;;
    cpu) llama_img="${LLAMA_CPU_IMAGE:-ghcr.io/ggml-org/llama.cpp:server-b10524}" ;;
    *) return 1 ;;
  esac
  for img in \
    "$llama_img" \
    "${LITELLM_IMAGE:-ghcr.io/berriai/litellm:v1.94.0}" \
    "${SEARXNG_IMAGE:-ghcr.io/searxng/searxng:2026.8.20-8d3dd0cd4}" \
    "${SANDBOX_IMAGE:-homelab-ai-sandbox:0.1.0}" \
    "${POSTGRES_IMAGE:-postgres:18.6-bookworm}"; do
    docker image inspect "$img" >/dev/null || return 1
  done
}


t9() {
  container_running homelab-ai-postgres || return 1
  docker exec homelab-ai-postgres pg_isready \
    -U "${POSTGRES_USER:-homelab_ai}" \
    -d "${POSTGRES_DB:-homelab_ai}" >/dev/null 2>&1 || return 1
  [[ "$(docker exec homelab-ai-postgres psql \
    -U "${POSTGRES_USER:-homelab_ai}" \
    -d "${POSTGRES_DB:-homelab_ai}" \
    -Atqc 'SELECT 1;')" == "1" ]]
}

require_docker || exit 1
run_test 1 "llama-server responds" t1
run_test 2 "LiteLLM responds" t2
run_test 3 "LiteLLM reaches llama-server" t3
run_test 4 "SearXNG responds" t4
run_test 5 "Sandbox executes code as non-root" t5
run_test 6 "Internal project network works" t6
run_test 7 "Sandbox isolation invariants" t7
run_test 8 "Required image set is resolvable for export" t8
run_test 9 "PostgreSQL healthy" t9

printf '\n==============================\n'
if (( failures == 0 )); then
  echo "PASS: all 9 smoke tests passed"
  exit 0
else
  echo "FAIL: $failures test(s) failed"
  exit 1
fi
