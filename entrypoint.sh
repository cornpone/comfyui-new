#!/bin/bash
set -e
if [ ! -e "/workspace/ComfyUI" ]; then
  ln -s "/home/app/ComfyUI" "/workspace/ComfyUI"
fi
if [ ! -e "/workspace/venv" ]; then
  ln -s "/home/app/venv" "/workspace/venv"
fi
if [ -x "/usr/bin/code-server" ]; then
  echo "Starting code-server..."
  /usr/bin/code-server --bind-addr 0.0.0.0:8080 --auth none /workspace &
else
  echo "code-server not found, skipping startup."
fi
echo "Starting ComfyUI..."
python /home/app/ComfyUI/main.py --listen 0.0.0.0 --port 8188
