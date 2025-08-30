FROM python:3.10-slim
ARG DEBIAN_FRONTEND=noninteractive

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git ffmpeg libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
    fonts-dejavu-core tini rsync build-essential \
 && rm -rf /var/lib/apt/lists/*

# Code-Server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Non-root + venv
ARG USER=app
RUN useradd -m -s /bin/bash ${USER}
USER ${USER}
WORKDIR /home/${USER}
RUN python -m venv /home/${USER}/venv
ENV PATH=/home/${USER}/venv/bin:$PATH
ENV PIP_NO_INPUT=1 PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_DEFAULT_TIMEOUT=100 PIP_NO_CACHE_DIR=1

# Python deps (NumPy 1.x + OpenCV 4.10 track)
COPY constraints.txt requirements-base.txt requirements-nodes.txt /tmp/
RUN pip install -c /tmp/constraints.txt -r /tmp/requirements-base.txt \
 && pip install -c /tmp/constraints.txt -r /tmp/requirements-nodes.txt \
 && pip install git+https://github.com/ltdrdata/img2texture.git \
               git+https://github.com/ltdrdata/cstr \
               git+https://github.com/ltdrdata/ffmpy.git

# ComfyUI (robust tarball fetch with fallbacks)
ARG COMFY_REF=refs/heads/master
RUN set -eux; \
  for ref in "$COMFY_REF" "refs/heads/master" "refs/heads/main"; do \
    url="https://codeload.github.com/comfyanonymous/ComfyUI/tar.gz/${ref}"; \
    echo "Trying $url"; \
    if curl -fLs -o /tmp/ComfyUI.tgz "$url"; then echo "Downloaded $ref"; break; fi; \
  done; \
  [ -s /tmp/ComfyUI.tgz ]; \
  topdir="$(tar -tzf /tmp/ComfyUI.tgz | head -1 | cut -f1 -d/)"; \
  tar -xzf /tmp/ComfyUI.tgz -C /home/${USER}; rm -f /tmp/ComfyUI.tgz; \
  mv "/home/${USER}/${topdir}" "/home/${USER}/ComfyUI"

# Persist caches to PV
ENV HF_HOME=/workspace/.cache/huggingface \
    TORCH_HOME=/workspace/.cache/torch \
    TORCHINDUCTOR_CACHE_DIR=/workspace/.cache/torch/inductor \
    TRITON_CACHE_DIR=/workspace/.cache/triton \
    XDG_CACHE_HOME=/workspace/.cache \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility

# Optional kernel warmup (will no-op on CI)
COPY --chown=${USER}:${USER} warmup.py /home/${USER}/warmup.py
RUN python /home/${USER}/warmup.py || true

# Entrypoint
COPY --chown=${USER}:${USER} --chmod=0755 entrypoint.sh /home/${USER}/entrypoint.sh

EXPOSE 8188 8080
ENTRYPOINT ["/usr/bin/tini","-s","--"]
CMD ["/home/app/entrypoint.sh"]
