# Homelab AI — Portable Milestone 1

This repository prepares a small, isolated Docker stack on a temporary NVIDIA PC and keeps the GPU-dependent part replaceable for a future AMD PC.

## Scope

Included now:

- `homelab-ai-llama` — llama.cpp / llama-server
- `homelab-ai-litellm` — stable OpenAI-compatible gateway
- `homelab-ai-searxng` — private search service
- `homelab-ai-sandbox` — non-root coding sandbox
- `homelab-ai-net` — dedicated Docker bridge network

Not included: Open WebUI, OpenJarvis, n8n, Qdrant, ChromaDB, LightRAG, Evolution API, MCP integrations, training, clustering, CAD/CAE automation.

## Safety boundary

The existing Docker installation is treated as foreign infrastructure. Project scripts never run global cleanup commands, never mount `/var/run/docker.sock`, and never stop/remove objects that are not part of Compose project `homelab-ai`.

The project intentionally uses fixed names:

- containers: `homelab-ai-*`
- network: `homelab-ai-net`
- project-owned sandbox image: `homelab-ai-sandbox:0.1.0`

Configurations, models, SearXNG data, logs and workspace are project-local bind mounts.

## Architecture

```text
client
  |
  v
homelab-ai-litellm :4000
  |
  v
homelab-ai-llama :8080 (internal only)
  |
  +-- NVIDIA CUDA today
  +-- AMD Vulkan/ROCm later after validation

homelab-ai-searxng :8888 (localhost only)
homelab-ai-sandbox (no host port)
```

## First run on the NVIDIA development PC

```bash
cd ~/homelab-ai
./scripts/setup.sh
./scripts/preflight.sh nvidia
./scripts/download-model.sh
./scripts/build.sh nvidia
./scripts/start.sh nvidia
./scripts/test.sh nvidia
```

Stop only this project:

```bash
./scripts/stop.sh nvidia
```

Inspect only this project:

```bash
./scripts/status.sh nvidia
```

## Export

Project/config only:

```bash
./scripts/export.sh
```

Include exact Docker images:

```bash
./scripts/export.sh --with-images
```

Include images plus the smoke-test model:

```bash
./scripts/export.sh --with-images --with-models
```

The resulting `.tar.gz` and SHA256 file are written under `package/`.

## Important

`compose.amd.yml` is a prepared candidate, not a validation claim. Read `docs/amd-migration.md` on the future AMD machine before enabling it.
