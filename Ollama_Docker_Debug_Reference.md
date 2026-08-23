# Ollama Docker Debug Reference

## System Hardware

See `SYSTEM_ARCHITECTURE.md` for the canonical hardware/storage/network reference. Summary as of 2026-08-23:

| Component | Spec |
|-----------|------|
| CPU | AMD Ryzen 9 5950X |
| GPU | NVIDIA RTX 3060 12GB (driver 580.173.02) |
| RAM | 64GB |
| OS | Ubuntu 24.04.4 LTS, kernel 6.17.0-35-generic |

---

## Running Containers

| Container | Image | Status | Ports |
|-----------|-------|--------|-------|
| `ollama` | ollama/ollama | Up | 0.0.0.0:11434→11434 |
| `open-webui` | ghcr.io/open-webui/open-webui:main | Up (healthy) | 0.0.0.0:3000→8080 |

`open-webui` is a browser UI in front of the `ollama` API (port 11434) — no separate model management, it talks to the same Ollama instance documented below.

---

## Ollama Docker Setup

- Ollama runs inside a Docker container named `ollama`
- All commands must be prefixed with `docker exec ollama`
- Use `docker exec -it ollama` for interactive sessions (e.g. `ollama run`)
- Modelfiles must be copied into the container via `docker cp` before use

---

## Current Models

```
NAME                      SIZE
qwen2.5:14b-instruct      9.0 GB
mistral-offload:latest    4.4 GB
mistral:7b-instruct       4.4 GB
```

`mistral-offload` is a custom CPU-offload variant of `mistral:7b-instruct` (below). `qwen2.5:14b-instruct` runs as-is, no custom Modelfile.

---

## mistral-offload Model

- **Base model:** `mistral:7b-instruct`
- **Custom name:** `mistral-offload`
- **`num_gpu`:** 20 of 32 total layers on GPU; remainder offloads to system RAM
- **Modelfile location (host):** `~/Modelfile`
- **Modelfile location (container):** `/Modelfile`

### Modelfile Contents

```
FROM mistral:7b-instruct
PARAMETER num_gpu 20
```

---

## CPU Offload Strategy

- **Goal:** Extend effective context window beyond the 12GB VRAM limit using system RAM
- `num_gpu` controls the GPU/RAM layer split
  - Lower value → more RAM offload → larger context capacity → slower inference
  - Higher value → more GPU layers → faster inference → less context headroom
- Mistral 7B has 32 transformer layers total (`num_gpu 0` = fully CPU, `num_gpu 32` = fully GPU)
- `ollama ps` shows live VRAM usage and offload status

---

## Key Commands

```bash
# Copy Modelfile into container
docker cp Modelfile ollama:/Modelfile

# Create custom model from Modelfile
docker exec ollama ollama create mistral-offload -f /Modelfile

# Run model (interactive)
docker exec -it ollama ollama run mistral-offload

# Check VRAM usage and offload status
docker exec ollama ollama ps

# List all models in container
docker exec ollama ollama list

# Check both containers' status
docker ps -a
```