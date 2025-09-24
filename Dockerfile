# --- Stage 1: The Builder ---
# This stage builds our entire application environment.
FROM python:3.10-slim-bookworm AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG USER=app

# Install build-time system dependencies.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git build-essential \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create user.
RUN useradd -m -s /bin/bash ${USER}
WORKDIR /home/${USER}

# Create and activate a virtual environment.
RUN python -m venv /home/${USER}/venv
ENV PATH=/home/${USER}/venv/bin:$PATH

# Install all Python dependencies from our single, unified requirements file.
ENV PIP_CACHE_DIR=/tmp/pip-cache
ENV PIP_EXTRA_INDEX_URL="https://download.pytorch.org/whl/cu121"
COPY requirements.txt /tmp/
RUN pip install --upgrade pip && pip install -r /tmp/requirements.txt

# --- Stage 2: The Final Runtime Image ---
# This stage creates the lean, final image.
FROM python:3.10-slim-bookworm

ARG DEBIAN_FRONTEND=noninteractive
ARG USER=app

# Install only essential RUNTIME system dependencies.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
    fonts-dejavu-core tini rsync git curl \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install code-server.
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Create user.
RUN useradd -m -s /bin/bash ${USER}
USER ${USER}
WORKDIR /home/${USER}

# Copy the pre-built Python environment from the builder.
COPY --from=builder --chown=${USER}:${USER} /home/${USER}/venv /home/${USER}/venv

# Now, clone a pristine copy of ComfyUI and custom nodes into a temporary location.
# This will be used to populate the user's workspace on first launch.
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /home/app/ComfyUI_pristine && \
    cd /home/app/ComfyUI_pristine/custom_nodes && \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git && \
    git clone https://github.com/Comfy-Org/ComfyUI-Manager.git

# Copy the configuration and entrypoint scripts.
COPY --chown=${USER}:${USER} extra_model_paths.yaml /home/app/ComfyUI_pristine/extra_model_paths.yaml
COPY --chown=${USER}:${USER} --chmod=0755 entrypoint.sh /home/app/entrypoint.sh

# Set the environment and expose ports.
ENV PATH=/home/${USER}/venv/bin:$PATH
EXPOSE 8188 8080
ENTRYPOINT ["/usr/bin/tini", "-s", "--"]
CMD ["/home/app/entrypoint.sh"]
