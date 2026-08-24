# Homelab AI — Design Specification

Date: 2026-08-23
Status: Approved design, pending user review of written spec

## Goal

Prepare a portable Docker project named `homelab-ai` on a temporary NVIDIA development PC, without modifying or depending on the existing Docker/Ollama project. The package must later move to a future AMD Windows 11 + WSL2 system with minimal manual work.

## Core constraints

- Existing Docker containers, networks, volumes, images and Ollama project are out of scope and must not be modified.
- No global Docker cleanup or destructive commands.
- No `docker.sock` mounts.
- No privileged containers.
- All project-owned objects use the `homelab-ai-` prefix where practical.
- The project uses one dedicated Docker network: `homelab-ai-net`.
- Configuration, models, data, logs and workspace remain external to images.
- The GPU-specific implementation is isolated to `llama-server`.

## Architecture

```text
client
  |
  v
LiteLLM
  |
  v
llama-server
  |
  +--> NVIDIA/CUDA on the temporary PC
  +--> AMD Vulkan/ROCm on the future PC, after validation

SearXNG       independent service
Coding Sandbox independent non-root service
```

LiteLLM is the stable OpenAI-compatible gateway. Clients must not depend directly on `llama-server`.

## Services

### homelab-ai-llama

- Runs `llama-server`.
- Uses CUDA only in the NVIDIA override.
- Reads GGUF models from `./models` via bind mount.
- Model files are not embedded in Docker images.
- No direct host port is required by default; internal reachability is sufficient.

### homelab-ai-litellm

- GPU-independent.
- Uses external YAML configuration.
- Routes requests to `http://homelab-ai-llama:8080` or the equivalent Compose service DNS name.
- Exposes a configurable localhost-only host port, default 4000.
- No database, Redis or additional service in milestone 1.

### homelab-ai-searxng

- GPU-independent.
- Uses external configuration and project-local persistent cache/data as needed.
- Exposes a configurable localhost-only host port, default 8888.
- No MCP integration in milestone 1.

### homelab-ai-sandbox

- Separate custom image.
- Non-root user.
- No privileged mode.
- No Docker socket.
- No host networking.
- `cap_drop: ALL` and `no-new-privileges` where compatible.
- Dedicated `./workspace` bind mount only.
- Includes Python, shell, Git, GCC/G++, Make, CMake and minimal CLI tools.
- CPU, memory and process limits are configurable.

## Storage strategy

Prefer project-local bind mounts for portability:

```text
homelab-ai/
  config/
  models/
  data/
  logs/
  workspace/
```

Named Docker volumes are not used initially unless a concrete service requirement justifies one. This makes transfer to the future PC straightforward and keeps important state visible.

## Compose layout

- `compose.yml`: hardware-independent services and shared configuration.
- `compose.nvidia.yml`: NVIDIA/CUDA-specific llama-server settings only.
- `compose.amd.yml`: future AMD-specific override, clearly marked unvalidated until the target PC is available.

The project is always invoked explicitly as project `homelab-ai`.

## Isolation strategy

A read-only preflight script will:

- verify Docker availability;
- inspect Docker/Compose version;
- inspect NVIDIA GPU availability on the temporary PC;
- verify free disk space;
- check target host ports;
- detect collisions for project-owned names;
- stop rather than modify anything ambiguous.

The preflight will never stop, remove or alter foreign containers, networks, volumes or images.

## Networking

One dedicated network:

`homelab-ai-net`

Only project services join it. Service-to-service communication uses Docker DNS names, not hardcoded IP addresses.

Default host exposure:

- LiteLLM: `127.0.0.1:4000`
- SearXNG: `127.0.0.1:8888`
- llama-server: internal only by default
- sandbox: no host port

Ports remain configurable in `.env`.

## Scripts

The package will include at least:

- `scripts/preflight.sh`
- `scripts/build.sh`
- `scripts/start.sh`
- `scripts/stop.sh`
- `scripts/status.sh`
- `scripts/test.sh`
- `scripts/export.sh`
- `scripts/import.sh`

All scripts act only on the `homelab-ai` Compose project and project-owned files/images.

## Testing

`./scripts/test.sh` will report PASS/FAIL per test and cover:

1. llama-server responds.
2. LiteLLM responds.
3. LiteLLM reaches llama-server.
4. SearXNG responds.
5. Sandbox executes code.
6. Internal project network works.
7. Sandbox isolation/security invariants are checked.
8. Project images are exportable.

Tests must not mutate the pre-existing Ollama project.

## Export/import

Export produces a portable package containing:

- Compose files;
- Dockerfiles;
- configs;
- scripts;
- docs;
- metadata/manifests;
- `.env.example`;
- project Docker images exported with `docker save` when requested.

Only `homelab-ai` images are exported.

The future PC workflow is:

```text
copy package
  -> import/load project images
  -> verify AMD GPU backend prerequisites
  -> configure AMD llama-server override
  -> docker compose up
  -> smoke tests
```

## AMD migration policy

The AMD path is prepared but not claimed to work until tested on the target machine.

The future migration guide will explicitly document:

- Windows 11 + WSL2 prerequisites;
- AMD driver prerequisites;
- Vulkan/ROCm verification;
- backend/image selection for llama-server;
- files that change;
- validation tests to run before declaring success.

LiteLLM, SearXNG, sandbox, project storage layout and generic scripts remain unchanged.

## Tooling workflow on the temporary PC

Primary shell: Ubuntu/WSL2 terminal.

Use PowerShell only for Windows-level tasks such as checking WSL state, Docker Desktop integration or driver-related diagnostics. Command Prompt is not required for the normal project workflow.

## Definition of done

The milestone is complete only when the NVIDIA build has been run on the temporary PC and the requested smoke/export checks pass without touching foreign Docker resources. The AMD backend remains explicitly unvalidated until the future PC is available.
