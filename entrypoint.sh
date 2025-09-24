#!/bin/bash
set -e

# Start code-server in the background.
if [ -x "/usr/bin/code-server" ]; then
  echo "Starting code-server..."
  /usr/bin/code-server --bind-addr 0.0.0.0:8080 --auth none /workspace &
else
  echo "code-server not found, skipping startup."
fi

# Start ComfyUI. It will automatically find and use extra_model_paths.yaml.
# No symlinks or other tricks are needed.
echo "Starting ComfyUI..."
python /home/app/ComfyUI/main.py --listen 0.0.0.0 --port 8188
