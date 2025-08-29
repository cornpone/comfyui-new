#!/usr/bin/env bash
set -euo pipefail

# --- Config (single root; override with env MODELS_ROOT if you ever want) ---
MODELS_ROOT="${MODELS_ROOT:-/workspace/models}"
COMFY_DIR="/workspace/ComfyUI"
EXTRA_YAML="$COMFY_DIR/extra_model_paths.yaml"
OUTPUT_DIR="/workspace/output"
CATS=(checkpoints loras vae controlnet clip clip_vision upscale_models unet embeddings)

# --- Caches (harmless) ---
mkdir -p /workspace/.cache/torch/inductor /workspace/.cache/triton /workspace/.cache/huggingface

# --- First-run: copy code to PV (copy-only; never delete) ---
if [ ! -d "$COMFY_DIR" ]; then
  mkdir -p "$COMFY_DIR"
  rsync -a /home/app/ComfyUI/ "$COMFY_DIR"/ || true
fi

# --- Ensure model/output dirs (no touching existing content) ---
mkdir -p "$MODELS_ROOT" "$OUTPUT_DIR"
for c in "${CATS[@]}"; do mkdir -p "$MODELS_ROOT/$c"; done

# --- Generate extra_model_paths.yaml (single-path, block scalars) ---
if [ ! -f "$EXTRA_YAML" ] || [ "${REGEN_EXTRA_PATHS:-0}" = "1" ]; then
  {
    for c in "${CATS[@]}"; do
      echo "$c: |"
      echo "  ${MODELS_ROOT}/${c}"
    done
  } > "$EXTRA_YAML"
fi

# --- Code-Server (auth with PASSWORD if set) ---
CS_AUTH="none"; [ -n "${PASSWORD:-}" ] && CS_AUTH="password"
code-server --bind-addr 0.0.0.0:8080 --auth "$CS_AUTH" /workspace &

# --- Ensure ComfyUI frontend present (self-heal, no-op if already installed) ---
if ! /home/app/venv/bin/pip show comfyui-frontend-package >/dev/null 2>&1; then
  /home/app/venv/bin/pip install --no-cache-dir -r "$COMFY_DIR/requirements.txt"
fi

# --- Run ComfyUI ---
cd "$COMFY_DIR"
exec /home/app/venv/bin/python main.py --listen 0.0.0.0 --port 8188
