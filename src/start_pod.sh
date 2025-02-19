#!/usr/bin/env bash

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
export LD_PRELOAD="${TCMALLOC}"

# there are requirement files in the custom_nodes folder, so we need to install them
cd /comfyui/custom_nodes && \
    for req in $(find . -name "requirements.txt"); do \
        pip3 install -r $req; \
    done

cd /runpod-volume/custom_nodes && \
    for req in $(find . -name "requirements.txt"); do \
        pip3 install -r $req; \
    done

# start comfyui    
echo "runpod-pod-comfy: Starting ComfyUI"
python3 /comfyui/main.py --auto-launch --listen --disable-metadata &

# Keep the container running indefinitely
sleep infinity