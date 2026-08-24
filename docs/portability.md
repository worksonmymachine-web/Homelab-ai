# Portability

## What travels unchanged

- Compose common file
- LiteLLM configuration
- SearXNG configuration
- coding sandbox Dockerfile
- scripts
- documentation
- models directory / GGUF files if included in export
- workspace if included in export

## What is hardware-specific

Only the llama-server GPU override and host GPU prerequisites.

Current temporary PC:

```text
compose.yml + compose.nvidia.yml
```

Future AMD PC:

```text
compose.yml + compose.amd.yml
```

## Why bind mounts are used

Important state is stored in visible project directories rather than anonymous Docker volumes. A container can be recreated without losing the model or workspace, and a project transfer is a normal filesystem copy/export.

## Docker images

`export.sh --with-images` performs a real `docker save` of the exact image set currently used for the NVIDIA milestone and records image IDs/digests in metadata. The future AMD llama image is not silently substituted for the CUDA image.
