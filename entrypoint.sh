#!/usr/bin/env bash
set -euo pipefail

COMFY_ROOT_PV="/workspace/ComfyUI"
MODELS_A="$COMFY_ROOT_PV/models"
MODELS_B="/workspace/models"
OUTPUT_DIR="/workspace/output"
EXTRA_YAML="$COMFY_ROOT_PV/extra_model_paths.yaml"
PATHS_LOG="/workspace/startup.paths"
CATS=(checkpoints loras vae controlnet clip clip_vision upscale_models unet embeddings)

# Caches (harmless)
mkdir -p /workspace/.cache/torch/inductor /workspace/.cache/triton /workspace/.cache/huggingface

# First-run code copy only (NO deletes)
if [ ! -d "$COMFY_ROOT_PV" ]; then
  mkdir -p "$COMFY_ROOT_PV"
  rsync -a /home/app/ComfyUI/ "$COMFY_ROOT_PV"/ || true
fi

# Ensure common dirs (never touch existing content)
mkdir -p "$MODELS_A" "$MODELS_B" "$OUTPUT_DIR"

# Generate extra_model_paths.yaml once (or set REGEN_EXTRA_PATHS=1 to force)
if [ ! -f "$EXTRA_YAML" ] || [ "${REGEN_EXTRA_PATHS:-0}" = "1" ]; then
  {
    for cat in "${CATS[@]}"; do
      echo "$cat: [$MODELS_A/$cat, $MODELS_B/$cat, /workspace/$cat]"
    done
  } > "$EXTRA_YAML"
fi

# Log scan paths
{
  echo "=== ComfyUI model scan paths ($(date -u +'%Y-%m-%dT%H:%M:%SZ')) ==="
  cat "$EXTRA_YAML"
} > "$PATHS_LOG" || true

# Code-Server
CS_AUTH="none"; [ -n "${PASSWORD:-}" ] && CS_AUTH="password"
code-server --bind-addr 0.0.0.0:8080 --auth "$CS_AUTH" /workspace &

# Ensure ComfyUI frontend present (self-heal)
if ! /home/app/venv/bin/pip show comfyui-frontend-package >/dev/null 2>&1; then
  /home/app/venv/bin/pip install --no-cache-dir -r "$COMFY_ROOT_PV/requirements.txt"
fi

cd "$COMFY_ROOT_PV"
exec /home/app/venv/bin/python main.py --listen 0.0.0.0 --port 8188
