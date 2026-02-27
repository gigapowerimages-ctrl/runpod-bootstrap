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


# -------------------------
# WAN LORAS (VIDEO ONLY)
# -------------------------

if [ "${MODE:-image}" = "video" ]; then

  echo "=== Installing WAN Video LoRAs ==="

  mkdir -p "$BASE_PATH/loras"
  cd "$BASE_PATH/loras" || exit 1

  if [ -z "${civitai_token:-}" ]; then
    echo "❌ civitai_token secret not set"
    exit 1
  fi

  declare -A LORAS=(

    [2315187]="wan_jiggle_lo"
    [2315167]="wan_jiggle_hi"

    [2073605]="wan_nsfwsks_hi"
    [2083303]="wan_nsfwsks_lo"

    [2484657]="wan_k3nk_hi"
    [2538990]="wan_k3nk_lo"

    [2370687]="wan_bbc_bj_hi"
    [2370744]="wan_bbc_bj_lo"

    [2464946]="wan_bbc_ride_hi"
    [2464985]="wan_bbc_ride_lo"

    [2553271]="wan_dr34ml4y_lo"
    [2553151]="wan_dr34ml4y_hi"

    [2273468]="wan_slop_hi"
    [2273467]="wan_slop_lo"

    [2235299]="wan_2xbj_hi"
    [2235288]="wan_2xbj_lo"

    [2195559]="wan_deep_hi"
    [2195625]="wan_deep_lo"

    [2517513]="wan_deepface_hi"
    [2517548]="wan_deepface_lo"
  )

  for id in "${!LORAS[@]}"; do
    name="${LORAS[$id]}.safetensors"

    if [ ! -f "$name" ]; then
      echo "⬇ Downloading $name..."

      curl -fL \
        -H "Authorization: Bearer ${civitai_token}" \
        "https://civitai.com/api/download/models/${id}?type=Model&format=SafeTensor" \
        -o "$name" || echo "⚠ Failed: $name"

    else
      echo "✔ $name already exists"
    fi
  done

  echo "✅ WAN LoRAs ready"

fi

