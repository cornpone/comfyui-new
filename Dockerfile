FROM python:3.10-slim-bookworm
ARG DEBIAN_FRONTEND=noninteractive

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git ffmpeg libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
    fonts-dejavu-core tini rsync build-essential \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Create a non-root user
ARG USER=app
RUN useradd -m -s /bin/bash ${USER}
USER ${USER}
WORKDIR /home/${USER}

# Create and set up a virtual environment
RUN python -m venv /home/${USER}/venv
ENV PATH=/home/${USER}/venv/bin:$PATH
# Move pip's cache to ephemeral storage, it doesn't need to be persisted
ENV PIP_CACHE_DIR=/tmp/pip-cache

# Python dependencies
# Use PyTorch's index for better compatibility
ENV PIP_EXTRA_INDEX_URL="https://download.pytorch.org/whl/cu121"
COPY constraints.txt requirements-base.txt requirements-nodes.txt /tmp/
RUN pip install --upgrade pip && \
    pip install -c /tmp/constraints.txt -r /tmp/requirements-base.txt && \
    pip install -c /tmp/constraints.txt -r /tmp/requirements-nodes.txt

# Clone ComfyUI from its Git repository
ARG COMFY_REF=master
RUN git clone --depth 1 --branch ${COMFY_REF} https://github.com/comfyanonymous/ComfyUI.git /home/${USER}/ComfyUI && \
    rm -rf /home/${USER}/ComfyUI/.git

# --- MODIFIED: Explicitly set COMFYUI_PATH for Impact-Pack installer ---
# This removes the warning and makes the build more robust.
RUN cd /home/${USER}/ComfyUI/custom_nodes && \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git && \
    cd ComfyUI-Impact-Pack && \
    COMFYUI_PATH=/home/app/ComfyUI /home/app/venv/bin/python install.py

# Set environment variables for persisting critical caches
# Model caches are persisted to the volume for faster startups.
# Smaller compiler caches are moved to ephemeral storage inside the container.
ENV HF_HOME=/workspace/.cache/huggingface \
    TORCH_HOME=/workspace/.cache/torch \
    XDG_CACHE_HOME=/workspace/.cache \
    TORCHINDUCTOR_CACHE_DIR=/tmp/torch-inductor-cache \
    TRITON_CACHE_DIR=/tmp/triton-cache \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility

# Optional kernel warmup
COPY --chown=${USER}:${USER} warmup.py /home/${USER}/warmup.py
RUN python /home/USER/warmup.py

# Entrypoint setup
COPY --chown=${USER}:${USER} --chmod=0755 entrypoint.sh /home/${USER}/entrypoint.sh
EXPOSE 8188 8080
ENTRYPOINT ["/usr/bin/tini", "-s", "--"]
CMD ["/home/app/entrypoint.sh"]
