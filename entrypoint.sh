#!/bin/bash
set -e

# --- MODIFIED: Removed the confusing symlink ---
# The extra_model_paths.yaml file now handles all data paths correctly.
# We no longer need to create a symlink in the workspace.

# Start code-server in the background, targeting the persistent workspace.
if [ -x "/usr/bin/code-server" ]; then
  echo "Starting code-server..."
  /usr/bin/code-server --bind-addr 0.0.0.0:8080 --auth none /workspace &
else
  echo "code-server not found, skipping startup."
fi

# Start ComfyUI. It will automatically find and use extra_model_paths.yaml.
echo "Starting ComfyUI..."
python /home/app/ComfyUI/main.py --listen 0.0.0.0 --port 8188
