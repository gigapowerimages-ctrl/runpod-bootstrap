#!/bin/bash
set -euo pipefail

echo "=== RUNPOD BOOTSTRAP START ==="

# Log everything
exec > >(tee -a /workspace/bootstrap.log) 2>&1

BASE_PATH="/workspace/ComfyUI/models"
MODE="${MODE:-image}"

echo "Mode: $MODE"

apt update -y
apt install -y unzip wget curl rclone

mkdir -p "$BASE_PATH/diffusion_models"
mkdir -p "$BASE_PATH/loras"
mkdir -p "$BASE_PATH/text_encoders"
mkdir -p "$BASE_PATH/vae"
mkdir -p "$BASE_PATH/wildcards"

# -------------------------
# CONFIGURE RCLONE FIRST
# -------------------------

echo "Configuring rclone..."

if [ -z "${rclone_gdrive_token:-}" ]; then
  echo "ERROR: rclone_gdrive_token not set"
  exit 1
fi

mkdir -p ~/.config/rclone

printf "[gdrive]\ntype = drive\nscope = drive\ntoken = %s\n" \
"$rclone_gdrive_token" > ~/.config/rclone/rclone.conf

if ! rclone about gdrive: > /dev/null 2>&1; then
  echo "ERROR: Failed to connect to Google Drive"
  exit 1
fi

echo "rclone configured successfully."

# ---------------- IMAGE MODE ----------------
if [ "$MODE" = "image" ]; then

  if [ -z "${civitai_token:-}" ]; then
    echo "civitai_token not set"
    exit 1
  fi

  cd "$BASE_PATH/diffusion_models"

  MODEL_VERSION_ID=2086298
  MODEL_NAME="qwen_image_model.safetensors"

  if [ ! -f "$MODEL_NAME" ]; then
    if ! curl -fL --retry 3 --retry-delay 5 \
      -H "Authorization: Bearer ${civitai_token}" \
      "https://civitai.com/api/download/models/${MODEL_VERSION_ID}?type=Model&format=SafeTensor" \
      -o "$MODEL_NAME"; then
      echo "WARNING: diffusion model download failed"
    fi
  fi

  cd "$BASE_PATH/text_encoders"

  if [ ! -f "qwen_2.5_vl_7b_fp8_scaled.safetensors" ]; then
    if ! curl -fL --retry 3 --retry-delay 5 \
      -o qwen_2.5_vl_7b_fp8_scaled.safetensors \
      "https://huggingface.co/Qwen/Qwen2.5-VL-7B-Instruct/resolve/main/qwen_2.5_vl_7b_fp8_scaled.safetensors"; then
      echo "WARNING: text encoder download failed"
    fi
  fi

  cd "$BASE_PATH/vae"

  if [ ! -f "Qwen_Image-VAE.safetensors" ]; then
    if ! curl -fL --retry 3 --retry-delay 5 \
      -o Qwen_Image-VAE.safetensors \
      "https://huggingface.co/Qwen/Qwen-Image/resolve/main/Qwen_Image-VAE.safetensors"; then
      echo "WARNING: VAE download failed"
    fi
  fi

fi

# ---------------- IMAGE MODE ----------------
if [ "$MODE" = "image" ]; then

  if [ -z "${civitai_token:-}" ]; then
    echo "civitai_token not set"
    exit 1
  fi

  cd "$BASE_PATH/diffusion_models"

  MODEL_VERSION_ID=2086298
  MODEL_NAME="qwen_image_model.safetensors"

  if [ ! -f "$MODEL_NAME" ]; then
    if ! curl -fL --retry 3 --retry-delay 5 \
      -H "Authorization: Bearer ${civitai_token}" \
      "https://civitai.com/api/download/models/${MODEL_VERSION_ID}?type=Model&format=SafeTensor" \
      -o "$MODEL_NAME"; then
      echo "WARNING: diffusion model download failed"
    fi
  fi

  cd "$BASE_PATH/text_encoders"

  if [ ! -f "qwen_2.5_vl_7b_fp8_scaled.safetensors" ]; then
    if ! curl -fL --retry 3 --retry-delay 5 \
      -o qwen_2.5_vl_7b_fp8_scaled.safetensors \
      "https://huggingface.co/Qwen/Qwen2.5-VL-7B-Instruct/resolve/main/qwen_2.5_vl_7b_fp8_scaled.safetensors"; then
      echo "WARNING: text encoder download failed"
    fi
  fi

  cd "$BASE_PATH/vae"

  if [ ! -f "Qwen_Image-VAE.safetensors" ]; then
    if ! curl -fL --retry 3 --retry-delay 5 \
      -o Qwen_Image-VAE.safetensors \
      "https://huggingface.co/Qwen/Qwen-Image/resolve/main/Qwen_Image-VAE.safetensors"; then
      echo "WARNING: VAE download failed"
    fi
  fi

fi

# -------------------------
# INSTALL LORAS FROM DRIVE
# -------------------------

echo "Downloading loras.zip from Drive..."

if rclone copy gdrive:runpod/image/loras.zip /workspace/; then
  unzip -o /workspace/loras.zip -d "$BASE_PATH/loras"
  rm /workspace/loras.zip
  echo "LoRAs installed."
else
  echo "WARNING: loras.zip not found"
fi

# -------------------------
# INSTALL WILDCARDS FROM DRIVE
# -------------------------

echo "Downloading wildcards.zip from Drive..."

if rclone copy gdrive:runpod/image/wildcards.zip /workspace/; then
  unzip -o /workspace/wildcards.zip -d "$BASE_PATH/wildcards"
  rm /workspace/wildcards.zip
  echo "Wildcards installed."
else
  echo "WARNING: wildcards.zip not found"
fi

# -------------------------
# GOOGLE DRIVE OUTPUT SYNC
# -------------------------

echo "Starting background Google Drive sync..."

mkdir -p /workspace/ComfyUI/output
rclone mkdir gdrive:runpod/outputs 2>/dev/null || true

nohup bash -c '
while true; do
  rclone sync /workspace/ComfyUI/output \
    gdrive:runpod/outputs \
    --ignore-existing \
    --transfers 4 \
    --checkers 4 \
    --fast-list
  sleep 30
done
' > /workspace/rclone.log 2>&1 &

echo "Drive sync running in background."

echo "=== RUNPOD BOOTSTRAP COMPLETE ==="
