#!/usr/bin/env bash
set -euo pipefail

# PV caches
mkdir -p /workspace/.cache/torch/inductor /workspace/.cache/triton /workspace/.cache/huggingface
# PV models/output
mkdir -p /workspace/models /workspace/output

# Link ComfyUI dirs to PV
if [ ! -L /home/app/ComfyUI/models ]; then
  if [ -d /home/app/ComfyUI/models ] && [ ! -L /home/app/ComfyUI/models ]; then
    rsync -a --remove-source-files /home/app/ComfyUI/models/ /workspace/models/ || true
    rm -rf /home/app/ComfyUI/models
  fi
  ln -sfn /workspace/models /home/app/ComfyUI/models
fi
if [ ! -L /home/app/ComfyUI/output ]; then
  if [ -d /home/app/ComfyUI/output ] && [ ! -L /home/app/ComfyUI/output ]; then
    rsync -a --remove-source-files /home/app/ComfyUI/output/ /workspace/output/ || true
    rm -rf /home/app/ComfyUI/output
  fi
  ln -sfn /workspace/output /home/app/ComfyUI/output
fi

# Code-Server (serves /workspace). Set PASSWORD env to require a password.
CS_AUTH="none"; [ -n "${PASSWORD:-}" ] && CS_AUTH="password"
code-server --bind-addr 0.0.0.0:8080 --auth "$CS_AUTH" /workspace &

# ComfyUI
cd /home/app/ComfyUI
exec /home/app/venv/bin/python main.py --listen 0.0.0.0 --port 8188
