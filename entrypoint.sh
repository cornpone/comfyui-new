#!/bin/bash
set -e

# Link the ComfyUI folder to /workspace for easier access
if [ ! -L "/workspace/ComfyUI" ]; then
  ln -s "/home/app/ComfyUI" "/workspace/ComfyUI"
fi

# Link the venv folder to /workspace
if [ ! -L "/workspace/venv" ]; then
  ln -s "/home/app/venv" "/workspace/venv"
fi

# --- DISABLED: Redundant pip install ---
# All dependencies are now pre-installed in the Docker image.
# if [ -f "/workspace/ComfyUI/requirements.txt" ]; then
#   pip install -r "/workspace/ComfyUI/requirements.txt"
# fi

# Start code-server in the background
if [ -x "/usr/bin/code-server" ]; then
  echo "Starting code-server..."
  /usr/bin/code-server --bind-addr 0.0.0.0:8080 --auth none /workspace &
else
  echo "code-server not found, skipping startup."
fi

# Start ComfyUI
echo "Starting ComfyUI..."
python /home/app/ComfyUI/main.py --listen 0.0.0.0 --port 8188
