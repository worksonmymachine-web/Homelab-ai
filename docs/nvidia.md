# NVIDIA Development PC

Validated environment from the initial setup session:

- WSL2 Ubuntu
- Docker Desktop reachable from Ubuntu
- NVIDIA GeForce RTX 3060
- 12,288 MiB VRAM
- WSL `nvidia-smi` available
- NVIDIA CUDA UMD reported as 13.3

The project therefore pins the current llama.cpp CUDA 13 server image in `.env.example`.

## Preflight

```bash
./scripts/preflight.sh nvidia
```

This is read-only with respect to foreign Docker objects. It checks the Docker daemon, Compose, GPU visibility, free space, host ports, and collisions with names reserved for this project.

## Build and start

```bash
./scripts/build.sh nvidia
./scripts/start.sh nvidia
./scripts/test.sh nvidia
```

If CUDA initialization fails, do not change the rest of the stack. Inspect `homelab-ai-llama` logs and keep troubleshooting isolated to the NVIDIA override / driver / llama image layer.
