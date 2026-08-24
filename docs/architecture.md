# Architecture

## Stable boundary

Applications must consume the OpenAI-compatible LiteLLM endpoint. They must not encode the llama-server URL as an application dependency.

```text
future apps -> LiteLLM -> llama-server -> GPU backend
```

This keeps the future NVIDIA-to-AMD change below the gateway boundary.

## Services

### llama

- container: `homelab-ai-llama`
- internal port: 8080
- model mount: `./models:/models:ro`
- host port: none
- current backend override: CUDA 13
- future candidate override: Vulkan, unvalidated

### LiteLLM

- container: `homelab-ai-litellm`
- host binding: `127.0.0.1:4000`
- config: `config/litellm/config.yaml`
- backend URL: `http://homelab-ai-llama:8080/v1`
- GPU-independent

### SearXNG

- container: `homelab-ai-searxng`
- host binding: `127.0.0.1:8888`
- config: `config/searxng/settings.yml`
- cache/data: `data/searxng/`
- GPU-independent

### Coding sandbox

- container: `homelab-ai-sandbox`
- custom image: `homelab-ai-sandbox:0.1.0`
- non-root UID/GID 10001
- no Docker socket
- no privileged mode
- no host network
- all Linux capabilities dropped
- `no-new-privileges`
- read-only container root filesystem
- writable project mount only at `/workspace`, plus bounded tmpfs `/tmp`

## Network

A dedicated bridge network is named exactly `homelab-ai-net`. The preflight script refuses to use an already-existing network with that name unless it has the expected project label.
