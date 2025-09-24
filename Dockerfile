# --- Stage 1: The Builder ---
FROM python:3.10-slim-bookworm AS builder
ARG DEBIAN_FRONTEND=noninteractive
ARG USER=app
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates git build-essential && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN useradd -m -s /bin/bash ${USER}
WORKDIR /home/${USER}
RUN python -m venv /home/${USER}/venv
ENV PATH=/home/${USER}/venv/bin:$PATH
ENV PIP_CACHE_DIR=/tmp/pip-cache
ENV PIP_EXTRA_INDEX_URL="https://download.pytorch.org/whl/cu121"
COPY constraints.txt requirements-base.txt requirements-nodes.txt /tmp/
RUN pip install --upgrade pip && pip install -c /tmp/constraints.txt -r /tmp/requirements-base.txt && pip install -c /tmp/constraints.txt -r /tmp/requirements-nodes.txt
ARG COMFY_REF=master
RUN git clone --depth 1 --branch ${COMFY_REF} https://github.com/comfyanonymous/ComfyUI.git /home/${USER}/ComfyUI && rm -rf /home/${USER}/ComfyUI/.git
RUN pip install -r /home/app/ComfyUI/requirements.txt

# --- MODIFIED: Add SAM2 and remove Manager's startup script ---
RUN cd /home/${USER}/ComfyUI/custom_nodes && \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git && \
    git clone https://github.com/Comfy-Org/ComfyUI-Manager.git && \
    rm /home/app/ComfyUI/custom_nodes/ComfyUI-Manager/startup.py && \
    cd ComfyUI-Impact-Pack && \
    COMFYUI_PATH=/home/app/ComfyUI /home/app/venv/bin/python install.py && \
    pip install git+https://github.com/facebookresearch/sam2

# --- Stage 2: The Final Image ---
FROM python:3.10-slim-bookworm
ARG DEBIAN_FRONTEND=noninteractive
ARG USER=app
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 fonts-dejavu-core tini rsync git curl && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL https://code-server.dev/install.sh | sh
RUN useradd -m -s /bin/bash ${USER}
USER ${USER}
WORKDIR /home/${USER}
COPY --from=builder --chown=${USER}:${USER} /home/${USER}/venv /home/${USER}/venv
COPY --from=builder --chown=${USER}:${USER} /home/${USER}/ComfyUI /home/${USER}/ComfyUI
COPY --chown=${USER}:${USER} extra_model_paths.yaml /home/${USER}/ComfyUI/extra_model_paths.yaml
ENV PATH=/home/${USER}/venv/bin:$PATH
ENV HF_HOME=/workspace/.cache/huggingface \
    TORCH_HOME=/workspace/.cache/torch \
    XDG_CACHE_HOME=/workspace/.cache \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility
COPY --chown=${USER}:${USER} warmup.py /home/${USER}/warmup.py
RUN python /home/${USER}/warmup.py
COPY --chown=${USER}:${USER} --chmod=0755 entrypoint.sh /home/${USER}/entrypoint.sh
EXPOSE 8188 8080
ENTRYPOINT ["/usr/bin/tini", "-s", "--"]
CMD ["/home/app/entrypoint.sh"]
