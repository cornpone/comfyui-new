#!/bin/bash
set -e

# On first boot, if the user's workspace is empty, copy the pristine
# ComfyUI directory structure over to get them started.
if [ ! -d "/workspace/ComfyUI" ]; then
  echo "Performing first-time setup of /workspace/ComfyUI..."
  mkdir -p /workspace/ComfyUI
  cp -r /home/app/ComfyUI_pristine/* /workspace/ComfyUI/
fi

# Start code-server in the background.
if [ -x "/usr/bin/code-server" ]; then
  echo "Starting code-server..."
  /usr/bin/code-server --bind-addr 0.0.0.0:8080 --auth none /workspace &
fi

# Start ComfyUI. All paths are handled by the YAML file. No installation needed.
echo "Starting ComfyUI..."
python /workspace/ComfyUI/main.py --listen 0.0.0.0 --port 8188
