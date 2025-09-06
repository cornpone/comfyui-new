#!/bin/bash
set -e

# --- MODIFIED: Safer check for existence ---
# Link the ComfyUI folder to /workspace for easier access, but only if it doesn't exist.
if [ ! -e "/workspace/ComfyUI" ]; then
  ln -s "/home/app/ComfyUI" "/workspace/ComfyUI"
fi

# Link the venv folder to /workspace, but only if it doesn't exist.
if [ ! -e "/workspace/venv" ]; then
  ln -s "/home/app/venv" "/workspace/venv"
fi

# Start code-server in the background
if [ -x "/usr/bin/code-server" ]; then
  echo "Starting code-server..."
  /usr/bin/code-server --bind-addr 0.0.0.0:8080 --auth none /workspace &
else
  echo "code-server not found, skipping startup."
fi

# --- MODIFIED: Added --disable-manager-auto-install ---
# Start ComfyUI, preventing the Manager from re-installing dependencies.
echo "Starting ComfyUI..."
python /home/app/ComfyUI/main.py --listen 0.0.0.0 --port 8188 --disable-manager-auto-install
