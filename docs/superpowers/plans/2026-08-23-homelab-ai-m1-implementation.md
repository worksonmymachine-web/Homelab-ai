# Homelab AI Milestone 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a portable, isolated Docker milestone containing llama-server, LiteLLM, SearXNG and a coding sandbox, test it on the temporary NVIDIA PC, and export it for a future AMD PC.

**Architecture:** Common services live in `compose.yml`; the GPU-specific llama image lives in backend overrides. Project-local bind mounts keep state transferable, and all scripts operate explicitly on Compose project `homelab-ai`.

**Tech Stack:** Docker Desktop, Docker Compose, WSL2 Ubuntu, llama.cpp, LiteLLM, SearXNG, Debian sandbox, Bash.

**Spec:** `docs/superpowers/specs/2026-08-23-homelab-ai-design.md`

## Global Constraints

- Never modify foreign Docker containers, networks, volumes or images.
- Never use global prune/cleanup operations.
- Never mount Docker socket into a service.
- Project container/network names use `homelab-ai-`.
- GPU specialization remains in llama-server backend overrides.
- AMD is not declared working until tested on target hardware.

---

### Task 1: Reproducible project scaffold

**Files:** `.env.example`, `.gitignore`, `compose.yml`, `compose.nvidia.yml`, `compose.amd.yml`, `scripts/lib.sh`, `scripts/setup.sh`, `scripts/preflight.sh`

**Produces:** isolated Compose project and read-only safety gate.

- [x] Create project-local directory layout and runtime environment template.
- [x] Define dedicated container names and `homelab-ai-net`.
- [x] Add collision, Docker, port, disk and GPU checks without mutation.
- [x] Validate shell syntax and Compose/YAML structure offline.

### Task 2: llama-server and model asset

**Files:** Compose files, `scripts/download-model.sh`, `docs/nvidia.md`, `docs/amd-migration.md`

**Produces:** pinned NVIDIA CUDA server path, prepared unvalidated AMD candidate, external GGUF asset flow.

- [x] Pin current llama.cpp server release tags.
- [x] Mount `./models` read-only.
- [x] Add a single official small Qwen GGUF smoke-test model download flow with disk/VRAM reporting.
- [ ] Run CUDA container on the temporary RTX PC and verify `/health`.

### Task 3: LiteLLM gateway

**Files:** `config/litellm/config.yaml`, `compose.yml`

**Produces:** localhost OpenAI-compatible gateway routing to internal llama-server DNS.

- [x] Configure fixed local model route.
- [x] Keep GPU dependencies out of LiteLLM.
- [ ] Verify a chat completion travels LiteLLM -> llama-server on the temporary PC.

### Task 4: SearXNG

**Files:** `config/searxng/settings.yml`, `compose.yml`

**Produces:** isolated, localhost-only SearXNG with JSON search format enabled.

- [x] Configure project-local config/cache mounts and generated secret.
- [ ] Verify HTTP response on temporary PC.

### Task 5: Coding sandbox

**Files:** `docker/sandbox/Dockerfile`, `compose.yml`

**Produces:** non-root build/code environment with bounded host access.

- [x] Install minimal Python/C/C++/CMake/Git toolchain.
- [x] Configure non-root UID, read-only rootfs, no privileges/caps, dedicated workspace and resource limits.
- [ ] Verify runtime security invariants on temporary PC.

### Task 6: Automated smoke tests

**Files:** `scripts/test.sh`, `docs/testing.md`

**Produces:** one command reporting PASS/FAIL for eight requested checks.

- [x] Implement service, routing, network, sandbox and image-set checks.
- [ ] Execute all tests on temporary NVIDIA PC.

### Task 7: Export/import and documentation

**Files:** `scripts/export.sh`, `scripts/import.sh`, `README.md`, `QUICKSTART.md`, portability docs.

**Produces:** transferable source/config package and optional Docker image/model archive.

- [x] Export only the defined project image set via `docker save` when requested.
- [x] Record metadata, image IDs/digests and SHA256 files.
- [x] Document future AMD manual validation boundary.
- [ ] Perform real export after NVIDIA tests pass.
- [ ] Validate archive integrity and document clean-host import on future/separate environment.
