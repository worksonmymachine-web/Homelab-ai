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

## Known gaps to close before/while validating on the real AMD PC

- **`scripts/export.sh`**: it now selects the llama image per backend (`nvidia`/`amd`/`cpu`) the same way `scripts/test.sh` (test 8) already did. Re-verify this branch-aware selection actually exports the right AMD image once `backend=amd` runs for real, since it has not been exercised on real AMD hardware yet.
- **`scripts/preflight.sh` (`amd` branch)**: today it only checks the `ALLOW_UNVALIDATED_AMD` gate; it does **not** perform any real hardware check equivalent to the `nvidia-smi` probe used for the `nvidia` branch. TODO once the WSL2 procedure is known: add an equivalent check (e.g. `rocminfo` for ROCm, or `vulkaninfo` for the Vulkan-first candidate) before allowing preflight to pass. Do not implement this blindly — the correct probe depends on which runtime path (Vulkan vs ROCm) is actually confirmed working on the target machine.
- **GPU tuning differences**: `LLAMA_GPU_LAYERS` and `LLAMA_CTX_SIZE` in `.env.example` are currently tuned for the CUDA/NVIDIA smoke test. Vulkan/ROCm on Strix Halo may support a different number of offloadable layers and a different safe context size — both values must be re-checked once the real layer count and memory behavior are known on the target hardware, not assumed to carry over from the NVIDIA baseline.
- **Rollback strategy**: if `backend=amd` validation fails partway through (`preflight`/`build`/`start`/`test`), do not attempt to patch the AMD path in place. Instead:
  1. `./scripts/stop.sh amd` (or `docker compose ... down` via the amd override) to remove any partially-started AMD containers;
  2. set `ALLOW_UNVALIDATED_AMD=0` again in `.env` to re-close the gate;
  3. resume validated work on `backend=cpu` (or `backend=nvidia` on the temporary PC) — both remain fully unaffected because no AMD-specific state is written outside `compose.amd.yml` and `.env`;
  4. only re-open `ALLOW_UNVALIDATED_AMD=1` after the specific failure is understood and `compose.amd.yml`/`docs/amd-migration.md` are updated accordingly.
