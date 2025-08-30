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
ENV PIP_NO_INPUT=1 PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_DEFAULT_TIMEOUT=100 PIP_NO_CACHE_DIR=1

# Python dependencies
# Use PyTorch's index for better compatibility
ENV PIP_EXTRA_INDEX_URL="https://download.pytorch.org/whl/cu121"
COPY constraints.txt requirements-base.txt requirements-nodes.txt /tmp/
RUN pip install --upgrade pip && \
    pip install -c /tmp/constraints.txt -r /tmp/requirements-base.txt && \
    pip install -c /tmp/constraints.txt -r /tmp/requirements-nodes.txt

# Download and install ComfyUI
ARG COMFY_REF=master
RUN set -eux; \
    url="https://codeload.github.com/comfyanonymous/ComfyUI/tar.gz/refs/heads/${COMFY_REF}"; \
    echo "Downloading ComfyUI from $url"; \
    curl -fLs -o /tmp/ComfyUI.tgz "$url"; \
    topdir="$(tar -tzf /tmp/ComfyUI.tgz | head -1 | cut -f1 -d/)"; \
    tar -xzf /tmp/ComfyUI.tgz -C /home/${USER}; \
    rm /tmp/ComfyUI.tgz; \
    mv "/home/${USER}/${topdir}" "/home/${USER}/ComfyUI"

# Set environment variables for persisting caches
ENV HF_HOME=/workspace/.cache/huggingface \
    TORCH_HOME=/workspace/.cache/torch \
    TORCHINDUCTOR_CACHE_DIR=/workspace/.cache/torch/inductor \
    TRITON_CACHE_DIR=/workspace/.cache/triton \
    XDG_CACHE_HOME=/workspace/.cache \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility

# Optional kernel warmup
COPY --chown=${USER}:${USER} warmup.py /home/${USER}/warmup.py
RUN python /home/${USER}/warmup.py

# Entrypoint setup
COPY --chown=${USER}:${USER} --chmod=0755 entrypoint.sh /home/${USER}/entrypoint.sh
EXPOSE 8188 8080
ENTRYPOINT ["/usr/bin/tini", "-s", "--"]
CMD ["/home/app/entrypoint.sh"]
