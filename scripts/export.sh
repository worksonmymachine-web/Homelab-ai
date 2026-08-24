#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib.sh"
load_env
require_docker

with_images=0
with_models=0
with_workspace=0
for arg in "$@"; do
  case "$arg" in
    --with-images) with_images=1 ;;
    --with-models) with_models=1 ;;
    --with-workspace) with_workspace=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

ts="$(date +%Y%m%d-%H%M%S)"
out="$PROJECT_DIR/package/homelab-ai-export-$ts"
mkdir -p "$out/project" "$out/metadata"

cp "$PROJECT_DIR"/{README.md,QUICKSTART.md,.gitignore,.env.example,compose.yml,compose.nvidia.yml,compose.amd.yml} "$out/project/"
cp -a "$PROJECT_DIR/config" "$PROJECT_DIR/docker" "$PROJECT_DIR/scripts" "$PROJECT_DIR/docs" "$out/project/"
mkdir -p "$out/project"/{models,data/searxng,logs,workspace,package}
touch "$out/project/models/.gitkeep" "$out/project/data/searxng/.gitkeep" "$out/project/logs/.gitkeep" "$out/project/workspace/.gitkeep" "$out/project/package/.gitkeep"

if (( with_models )); then cp -a "$PROJECT_DIR/models/." "$out/project/models/"; fi
if (( with_workspace )); then cp -a "$PROJECT_DIR/workspace/." "$out/project/workspace/"; fi

{
  echo "exported_at=$(date --iso-8601=seconds)"
  echo "source_host=$(hostname)"
  echo "docker_server=$(docker version --format '{{.Server.Version}}')"
  echo "compose=$(docker compose version --short)"
  echo "model_file=${MODEL_FILE:-}"
  echo "models_included=$with_models"
  echo "workspace_included=$with_workspace"
} > "$out/metadata/export.txt"

images=(
  "${LLAMA_NVIDIA_IMAGE:-ghcr.io/ggml-org/llama.cpp:server-cuda13-b10524}"
  "${LITELLM_IMAGE:-ghcr.io/berriai/litellm:v1.94.0}"
  "${SEARXNG_IMAGE:-ghcr.io/searxng/searxng:2026.8.20-8d3dd0cd4}"
  "${SANDBOX_IMAGE:-homelab-ai-sandbox:0.1.0}"
)

: > "$out/metadata/images.txt"
for img in "${images[@]}"; do
  if docker image inspect "$img" >/dev/null 2>&1; then
    digest="$(docker image inspect -f '{{index .RepoDigests 0}}' "$img" 2>/dev/null || true)"
    id="$(docker image inspect -f '{{.Id}}' "$img")"
    printf '%s\t%s\t%s\n' "$img" "$id" "$digest" >> "$out/metadata/images.txt"
  else
    echo "MISSING $img" >> "$out/metadata/images.txt"
  fi
done

if (( with_images )); then
  missing=0
  for img in "${images[@]}"; do docker image inspect "$img" >/dev/null 2>&1 || missing=1; done
  (( missing == 0 )) || { echo "FAIL: one or more required images are missing; run ./scripts/build.sh nvidia" >&2; exit 1; }
  mkdir -p "$out/images"
  docker save -o "$out/images/homelab-ai-images.tar" "${images[@]}"
  sha256sum "$out/images/homelab-ai-images.tar" > "$out/images/homelab-ai-images.tar.sha256"
fi

( cd "$PROJECT_DIR/package" && tar -czf "$(basename "$out").tar.gz" "$(basename "$out")" )
archive="$PROJECT_DIR/package/$(basename "$out").tar.gz"
sha256sum "$archive" > "$archive.sha256"
echo "PASS: export package created"
echo "$archive"
