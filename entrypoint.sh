#!/usr/bin/env bash
set -euo pipefail

# PV caches
mkdir -p /workspace/.cache/torch/inductor /workspace/.cache/triton /workspace/.cache/huggingface

# Bootstrap ComfyUI to PV on first run; then always run from PV
if [ ! -d /workspace/ComfyUI ]; then
  mkdir -p /workspace/ComfyUI
  rsync -a /home/app/ComfyUI/ /workspace/ComfyUI/ || true
fi
chown -R app:app /workspace/ComfyUI || true
COMFY_DIR="/workspace/ComfyUI"

# Persist models/output
mkdir -p /workspace/models /workspace/output
[ -L "$COMFY_DIR/models" ] || { [ -d "$COMFY_DIR/models" ] && rsync -a --remove-source-files "$COMFY_DIR/models/" /workspace/models/ || true; rm -rf "$COMFY_DIR/models"; ln -sfn /workspace/models "$COMFY_DIR/models"; }
[ -L "$COMFY_DIR/output" ] || { [ -d "$COMFY_DIR/output" ] && rsync -a --remove-source-files "$COMFY_DIR/output/" /workspace/output/ || true; rm -rf "$COMFY_DIR/output"; ln -sfn /workspace/output "$COMFY_DIR/output"; }

# Code-Server on PV root
CS_AUTH="none"; [ -n "${PASSWORD:-}" ] && CS_AUTH="password"
code-server --bind-addr 0.0.0.0:8080 --auth "$CS_AUTH" /workspace &

# --- New: ensure ComfyUI's frontend package is installed ---
# If ComfyUI updates its requirements on disk, this keeps the pod working without rebuilds.
if ! /home/app/venv/bin/pip show comfyui-frontend-package >/dev/null 2>&1; then
  echo "[entrypoint] Installing ComfyUI requirements (frontend package)..."
  /home/app/venv/bin/pip install --no-cache-dir -r "$COMFY_DIR/requirements.txt"
fi

# Launch ComfyUI; if it dies, keep the container alive for debugging
cd "$COMFY_DIR"
set +e
/home/app/venv/bin/python main.py --listen 0.0.0.0 --port 8188 |& tee /workspace/startup.log
status=$?
set -e
if [ $status -ne 0 ]; then
  echo "ComfyUI exited with status $status. See /workspace/startup.log . Keeping container alive for debugging."
  sleep infinity
fi
