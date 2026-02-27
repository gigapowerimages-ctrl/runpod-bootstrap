#!/bin/bash
set -euo pipefail

echo "=== RUNPOD BOOTSTRAP START ==="

# Log everything
exec > >(tee -a /workspace/bootstrap.log) 2>&1

BASE_PATH="/ComfyUI/models"
MODE="${MODE:-image}"

echo "Mode: $MODE"

apt update -y
apt install -y unzip wget curl rclone

mkdir -p "$BASE_PATH/diffusion_models"
mkdir -p "$BASE_PATH/loras"
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

      echo "WARNING: text encoder download failed"
    fi
  fi

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

      echo "WARNING: text encoder download failed"
    fi
  fi

      echo "WARNING: VAE download failed"
    fi
  fi

fi

# -------------------------
# INSTALL LORAS FROM DRIVE
# -------------------------

echo "Downloading loras.zip from Drive..."

if rclone copy gdrive:runpod/image/loras.zip /workspace/; then
mkdir -p "$BASE_PATH/loras"

unzip -o /workspace/loras.zip -d /workspace/tmp_loras

if [ -d /workspace/tmp_loras/loras ]; then
  mv /workspace/tmp_loras/loras/* "$BASE_PATH/loras/"
else
  mv /workspace/tmp_loras/* "$BASE_PATH/loras/"
fi

rm -rf /workspace/tmp_loras
rm /workspace/loras.zip

# -------------------------
# QWEN TEXT ENCODER
# -------------------------

echo "Downloading Qwen Text Encoder..."
mkdir -p "$BASE_PATH/text_encoders"
cd "$BASE_PATH/text_encoders"

wget -O qwen_2.5_vl_7b_fp8_scaled.safetensors \
https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors


# -------------------------
# QWEN VAE
# -------------------------

echo "Downloading Qwen VAE..."
mkdir -p "$BASE_PATH/vae"
cd "$BASE_PATH/vae"

wget -O qwen_image_vae.safetensors \
https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors

