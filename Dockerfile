# ---------- Stage 1: Wheel builder ----------
FROM python:3.10-slim AS wheels
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git build-essential ffmpeg \
 && rm -rf /var/lib/apt/lists/*
ENV PIP_NO_INPUT=1 PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_DEFAULT_TIMEOUT=100
WORKDIR /opt/build
COPY constraints.txt requirements-base.txt requirements-nodes.txt ./
RUN pip install --upgrade pip \
 && mkdir -p /opt/wheels \
 && pip download --dest /opt/wheels -c constraints.txt -r requirements-base.txt \
 && pip download --dest /opt/wheels -c constraints.txt -r requirements-nodes.txt \
 && pip download --dest /opt/wheels git+https://github.com/ltdrdata/img2texture.git \
 && pip download --dest /opt/wheels git+https://github.com/ltdrdata/cstr \
 && pip download --dest /opt/wheels git+https://github.com/ltdrdata/ffmpy.git

# ---------- Stage 2: Runtime ----------
FROM python:3.10-slim
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates ffmpeg libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
    fonts-dejavu-core tini rsync \
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
ENV PIP_NO_INPUT=1 PIP_DISABLE_PIP_VERSION_CHECK=1 PIP_DEFAULT_TIMEOUT=100

# Offline wheels
COPY --from=wheels /opt/wheels /opt/wheels
COPY constraints.txt requirements-base.txt requirements-nodes.txt /tmp/
RUN pip install --no-index --find-links=/opt/wheels -c /tmp/constraints.txt -r /tmp/requirements-base.txt \
 && pip install --no-index --find-links=/opt/wheels -c /tmp/constraints.txt -r /tmp/requirements-nodes.txt \
 && pip install --no-index --find-links=/opt/wheels img2texture cstr ffmpy

# ComfyUI (download tarball; no git)
ARG COMFY_COMMIT=32a95bba3c7e1b2f6f2a46f0f2c9a5c2e9b3d1a2
RUN mkdir -p /home/${USER}/ComfyUI \
 && curl -L "https://github.com/comfyanonymous/ComfyUI/archive/${COMFY_COMMIT}.tar.gz" \
 | tar -xz -C /home/${USER} \
 && mv /home/${USER}/ComfyUI-${COMFY_COMMIT} /home/${USER}/ComfyUI

# PV caches
ENV HF_HOME=/workspace/.cache/huggingface \
    TORCH_HOME=/workspace/.cache/torch \
    TORCHINDUCTOR_CACHE_DIR=/workspace/.cache/torch/inductor \
    TRITON_CACHE_DIR=/workspace/.cache/triton \
    XDG_CACHE_HOME=/workspace/.cache \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility

COPY warmup.py /home/${USER}/warmup.py
RUN python /home/${USER}/warmup.py || true

COPY entrypoint.sh /home/${USER}/entrypoint.sh
RUN chmod +x /home/${USER}/entrypoint.sh

EXPOSE 8188 8080
ENTRYPOINT ["/usr/bin/tini","--"]
CMD ["/home/app/entrypoint.sh"]
