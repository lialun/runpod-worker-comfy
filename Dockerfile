# Stage 1: Base image with common dependencies
FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04 AS base

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1
# Speed up some cmake builds
ENV CMAKE_BUILD_PARALLEL_LEVEL=8
# Virtual environment path
ENV VIRTUAL_ENV=/venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Install Python, git and other necessary tools
RUN apt-get update && apt install software-properties-common -y && add-apt-repository ppa:deadsnakes/ppa &&\
    apt-get install -y \
    python3.12 \
    python3.12-venv \
    python3.12-dev \
    python3-pip \
    git \
    wget \
    libgl1 \
    libgtk2.0-dev \
    unzip \
    && ln -sf /usr/bin/python3.12 /usr/bin/python \
    && python -m venv $VIRTUAL_ENV \
    && pip install --upgrade pip

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install comfy-cli using virtual environment
RUN pip install comfy-cli

# Install ComfyUI
RUN /usr/bin/yes | comfy --workspace /comfyui install --cuda-version 11.8 --nvidia --version 0.3.14 --skip-manager

# Change working directory to ComfyUI
WORKDIR /comfyui

# Install runpod using virtual environment
RUN pip install xformers runpod requests numba colour-science rembg pixeloe transparent-background insightface==0.7.3 onnxruntime onnxruntime-gpu colorama diffusers accelerate "clip_interrogator>=0.6.0" lark opencv-python sentencepiece spandrel matplotlib peft GitPython PyGithub matrix-client==0.4.0 transformers huggingface-hub>0.20 typer rich typing-extensions toml uv chardet clip-interrogator simpleeval cython facexlib ftfy timm numpy

# Create necessary directories
RUN mkdir -p /comfyui/models/checkpoints /comfyui/models/vae /comfyui/models/clip /comfyui/models/vae/flux/ /comfyui/models/loras/flux/ /comfyui/models/pulid/ /comfyui/models/insightface/models/ /comfyui/models/facexlib/

# Download  models
ARG MODEL_TYPE 
RUN if [ "$MODEL_TYPE" = "flux1-pulid" ]; then \
      wget -O models/unet/flux1-dev.safetensors http://localhost:8000/flux1-dev.safetensors && \
      wget -O models/clip/clip_l.safetensors http://localhost:8000/clip_l.safetensors && \
      wget -O models/clip/t5xxl_fp8_e4m3fn.safetensors http://localhost:8000/t5xxl_fp8_e4m3fn.safetensors && \
      wget -O models/vae/flux/flux-ae.safetensors http://localhost:8000/flux-ae.safetensors && \
      wget -O models/loras/flux/Hyper-FLUX.1-dev-8steps-lora.safetensors http://localhost:8000/Hyper-FLUX.1-dev-8steps-lora.safetensors && \
      wget -O models/pulid/pulid_flux_v0.9.1.safetensors http://localhost:8000/pulid_flux_v0.9.1.safetensors && \
      wget -O models/insightface/models/antelopev2.zip http://localhost:8000/antelopev2.zip && \
      unzip -d models/insightface/models/ models/insightface/models/antelopev2.zip && \
      wget -O models/facexlib/parsing_bisenet.pth http://localhost:8000/parsing_bisenet.pth && \
      wget -O models/facexlib/detection_Resnet50_Final.pth http://localhost:8000/detection_Resnet50_Final.pth ; \
    elif [ "$MODEL_TYPE" = "flux1-dev" ]; then \
      wget -O models/unet/flux1-dev.safetensors http://localhost:8000/flux1-dev.safetensors && \
      wget -O models/clip/clip_l.safetensors http://localhost:8000/clip_l.safetensors && \
      wget -O models/clip/t5xxl_fp8_e4m3fn.safetensors http://localhost:8000/t5xxl_fp8_e4m3fn.safetensors && \
      wget -O models/vae/flux/flux-ae.safetensors http://localhost:8000/flux-ae.safetensors && \
      wget -O models/loras/flux/Hyper-FLUX.1-dev-8steps-lora.safetensors http://localhost:8000/Hyper-FLUX.1-dev-8steps-lora.safetensors ; \
    fi

# Support for the network volume
ADD src/extra_model_paths.yaml ./

# Go back to the root
WORKDIR /

# Add scripts
ADD src/start.sh src/restore_snapshot.sh src/rp_handler.py test_input.json ./
RUN chmod +x /start.sh /restore_snapshot.sh

# Optionally copy the snapshot file
ADD *snapshot*.json /

# Restore the snapshot to install custom nodes
RUN /restore_snapshot.sh

# Start container
CMD ["/start.sh"]

