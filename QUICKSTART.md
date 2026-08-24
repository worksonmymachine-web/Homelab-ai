# QUICKSTART — Future PC / Fresh Installation

This guide is written to be usable without the original chat.

## 1. Requirements

Required on Windows:

- Windows 11 with WSL2
- Ubuntu WSL2
- Docker Desktop using the WSL2 backend
- WSL integration enabled for the Ubuntu distro

For the future AMD machine, do not assume GPU acceleration works merely because Docker works. Complete `docs/amd-migration.md` first.

Inside Ubuntu verify:

```bash
docker version
docker compose version
```

## 2. Place the package

Extract the exported archive to your Linux home filesystem, not into `C:\Program Files\Docker` and preferably not under `/mnt/c` or `/mnt/d`.

Target:

```text
/home/<user>/homelab-ai
```

Example:

```bash
cd ~
mkdir -p homelab-ai
# copy/extract project contents into ~/homelab-ai
cd ~/homelab-ai
```

## 3. Import Docker images

If the transfer package contains `images/homelab-ai-images.tar`, run from the project directory:

```bash
./scripts/import.sh ../images/homelab-ai-images.tar
```

If no image archive is present, `build.sh` will pull the pinned images that are required for the selected backend.

The NVIDIA llama image imported from the temporary PC is not an AMD backend.

## 4. Create local runtime configuration

```bash
./scripts/setup.sh
```

This copies `.env.example` to `.env` and generates a random SearXNG secret. Existing `.env` files are never overwritten.

Review:

```bash
nano .env
```

## 5. GPU configuration

### NVIDIA development PC

```bash
nvidia-smi
./scripts/preflight.sh nvidia
```

### Future AMD PC

Follow `docs/amd-migration.md`. Only after the actual GPU backend is validated should `ALLOW_UNVALIDATED_AMD=1` be set in `.env`.

## 6. Model

The default smoke-test model is:

```text
Qwen2.5-1.5B-Instruct-GGUF / Q4_K_M
qwen2.5-1.5b-instruct-q4_k_m.gguf
approximately 1.12 GiB
```

If it was exported with the package it should already be in `models/`.

Otherwise:

```bash
./scripts/download-model.sh
```

The script checks free disk space and reports detected NVIDIA VRAM before asking for permission to download.

## 7. Build / pull

NVIDIA:

```bash
./scripts/build.sh nvidia
```

Future validated AMD:

```bash
./scripts/build.sh amd
```

Only `homelab-ai-sandbox` is locally built. llama.cpp, LiteLLM and SearXNG use pinned upstream images.

## 8. Start

NVIDIA:

```bash
./scripts/start.sh nvidia
```

AMD after validation:

```bash
./scripts/start.sh amd
```

## 9. Verify status

```bash
./scripts/status.sh nvidia
```

or for AMD:

```bash
./scripts/status.sh amd
```

## 10. Smoke test

```bash
./scripts/test.sh nvidia
```

Expected final line:

```text
PASS: all 8 smoke tests passed
```

The tests cover llama-server, LiteLLM, LiteLLM-to-llama routing, SearXNG, sandbox execution, project network, sandbox isolation and the export image set.

## 11. Endpoints

Host-visible endpoints are bound to localhost only:

```text
LiteLLM  http://127.0.0.1:4000
SearXNG  http://127.0.0.1:8888
```

`llama-server` is intentionally not published to the host. Clients should use LiteLLM.

## 12. Stop

```bash
./scripts/stop.sh nvidia
```

or:

```bash
./scripts/stop.sh amd
```

This invokes Compose only for project `homelab-ai`. It does not run a global Docker stop or cleanup.

## 13. Update

Updates are deliberate, not automatic:

1. change one pinned image tag in `.env`/`.env.example`;
2. run `./scripts/build.sh <backend>`;
3. run `./scripts/start.sh <backend>`;
4. run `./scripts/test.sh <backend>`;
5. export a new package only after tests pass.

Do not replace pins with `latest` simply to update everything at once.
