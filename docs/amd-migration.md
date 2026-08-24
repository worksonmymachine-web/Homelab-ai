# AMD Migration — Future PC (Not Yet Validated)

## Status

**UNVALIDATED.** The target AMD PC is not available yet. This file deliberately separates preparation from claims of working GPU acceleration.

The architecture guide prefers Vulkan first for llama-server on the future AMD system, with ROCm considered after `rocminfo` is stable. `compose.amd.yml` therefore points to the pinned llama.cpp Vulkan server image as a candidate only.

## Preconditions on Windows 11 + WSL2

Before starting the stack:

1. install/update the AMD Windows driver version explicitly documented to support the target Ryzen/Radeon WSL2 path;
2. verify WSL2 and Ubuntu are healthy;
3. verify Docker Desktop WSL integration;
4. follow current AMD Radeon/Ryzen ROCm-on-WSL documentation for the exact target hardware;
5. verify the GPU is visible inside WSL using the method supported by that driver stack;
6. if evaluating ROCm, run `rocminfo` and confirm the expected GPU architecture is reported;
7. validate how the chosen GPU device/runtime is passed from WSL/Docker Desktop into the llama.cpp container.

## Why Compose does not invent a device mapping

A Linux-native `/dev/dri` or `/dev/kfd` mapping cannot be assumed to be the correct Windows+WSL2 Docker Desktop path for future hardware. Hardcoding it now would create false portability. Add/adjust the device/runtime portion of `compose.amd.yml` only after the real machine proves what is required.

## Validation gate

Keep this in `.env`:

```text
ALLOW_UNVALIDATED_AMD=0
```

After the GPU path has been verified and `compose.amd.yml` updated if necessary:

```text
ALLOW_UNVALIDATED_AMD=1
```

Then run:

```bash
./scripts/preflight.sh amd
./scripts/build.sh amd
./scripts/start.sh amd
./scripts/test.sh amd
```

Do not declare AMD migration complete until all smoke tests pass and llama-server logs show the intended AMD backend/device actually in use.

## Files expected to remain unchanged

- `compose.yml`
- LiteLLM config
- SearXNG config
- sandbox image
- network name
- model GGUF
- generic scripts

The hardware-specific work should remain concentrated in `compose.amd.yml`, `.env` image selection, and host driver/runtime setup.
