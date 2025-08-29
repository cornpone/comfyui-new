#!/usr/bin/env bash
set -euo pipefail

# Run ComfyUI from the PV
COMFY_DIR="/workspace/ComfyUI"

# First-run seed: copy baked code into the PV if ComfyUI isn't there yet.
# Copy-only; never overwrites existing files; never deletes anything.
if [ ! -f "$COMFY_DIR/main.py" ]; then
  mkdir -p "$COMFY_DIR"
  rsync -a --ignore-existing /home/app/ComfyUI/ "$COMFY_DIR"/ || true
fi

# If an old extra_model_paths.yaml exists it can break boot; remove by default.
# Set KEEP_EXTRA_PATHS=1 if you really want to keep a custom one.
if [ -z "${KEEP_EXTRA_PATHS:-}" ] && [ -f "$COMFY_DIR/extra_model_paths.yaml" ]; then
  rm -f "$COMFY_DIR/extra_model_paths.yaml"
fi

# Optional editor on :8080 (set PASSWORD env to require a password)
CS_AUTH="none"; [ -n "${PASSWORD:-}" ] && CS_AUTH="password"
code-server --bind-addr 0.0.0.0:8080 --auth "$CS_AUTH" /workspace &

# Make sure the ComfyUI frontend package is installed (no-op if already there)
if ! /home/app/venv/bin/pip show comfyui-frontend-package >/dev/null 2>&1; then
  /home/app/venv/bin/pip install --no-cache-dir -r "$COMFY_DIR/requirements.txt" || true
fi

# Launch ComfyUI
cd "$COMFY_DIR"
exec /home/app/venv/bin/python main.py --listen 0.0.0.0 --port 8188
