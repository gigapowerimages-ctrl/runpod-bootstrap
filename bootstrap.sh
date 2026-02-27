cat > bootstrap.sh << 'EOF'
#!/bin/bash
set -euo pipefail

echo "=== RUNPOD BOOTSTRAP START ==="

MODE="${MODE:-image}"
BASE_PATH="/ComfyUI/models"
COMFY_ROOT="/ComfyUI"

echo "Mode: $MODE"

# -------------------------
# BASIC PACKAGES
# -------------------------

apt update -y
apt install -y unzip wget curl rclone git

mkdir -p "$BASE_PATH/wildcards"

# -------------------------
# RCLONE CONFIG
# -------------------------

echo "Configuring rclone..."

if [ -z "${rclone_gdrive_token:-}" ]; then
  echo "❌ rclone_gdrive_token not set"
  exit 1
fi

mkdir -p ~/.config/rclone

printf "[gdrive]\ntype = drive\nscope = drive\ntoken = %s\n" \
"$rclone_gdrive_token" > ~/.config/rclone/rclone.conf

if ! rclone about gdrive: > /dev/null 2>&1; then
  echo "❌ Failed to connect to Google Drive"
  exit 1
fi

echo "✔ rclone configured"

# -------------------------
# INSTALL CUSTOM NODE (IMAGE MODE)
# -------------------------

if [ "$MODE" = "image" ]; then

  echo "=== Installing comfyui_gprompts ==="

  NODES_DIR="${COMFY_ROOT}/custom_nodes"
  REPO_DIR="${NODES_DIR}/comfyui_gprompts"

  if [ -d "$COMFY_ROOT" ] && [ -d "$NODES_DIR" ]; then

    if [ -d "$REPO_DIR" ]; then
      echo "✔ Updating comfyui_gprompts"
      git -C "$REPO_DIR" pull --ff-only || true
    else
      echo "⬇ Cloning comfyui_gprompts"
      git clone https://github.com/GadzoinksOfficial/comfyui_gprompts "$REPO_DIR"
    fi

    if [ -f "$REPO_DIR/requirements.txt" ]; then
      pip install -r "$REPO_DIR/requirements.txt"
    else
      pip install "$REPO_DIR"
    fi

    echo "✔ comfyui_gprompts ready"

  else
    echo "⚠ ComfyUI not found yet — skipping custom node install"
  fi
fi

# -------------------------
# QWEN BASE MODEL
# -------------------------

echo "Installing Qwen Base Model..."

cd "$BASE_PATH/diffusion_models"

if [ ! -f "qwen_image_fp8_e4m3fn.safetensors" ]; then
  wget -q --show-progress -O qwen_image_fp8_e4m3fn.safetensors \
  https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_fp8_e4m3fn.safetensors
else
  echo "✔ Qwen base model exists"
fi

# -------------------------
# QWEN VAE
# -------------------------

echo "Installing Qwen VAE..."

cd "$BASE_PATH/vae"

if [ ! -f "qwen_vae.safetensors" ]; then
  wget -q --show-progress -O qwen_vae.safetensors \
  https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_vae.safetensors
else
  echo "✔ Qwen VAE exists"
fi

# -------------------------
# QWEN TEXT ENCODER
# -------------------------

echo "Installing Qwen Text Encoder..."

cd "$BASE_PATH/text_encoders"

if [ ! -f "qwen_text_encoder.safetensors" ]; then
  wget -q --show-progress -O qwen_text_encoder.safetensors \
  https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_text_encoder.safetensors
else
  echo "✔ Qwen Text Encoder exists"
fi

# -------------------------
# IMAGE MODE DOWNLOADS
# -------------------------

if [ "$MODE" = "image" ]; then

  if [ -z "${civitai_token:-}" ]; then
    echo "❌ civitai_token not set"
    exit 1
  fi

  MODEL_ID=2086298
  MODEL_NAME="qwen_image_model.safetensors"

  if [ ! -f "$MODEL_NAME" ]; then
    curl -fL \
      -H "Authorization: Bearer ${civitai_token}" \
      "https://civitai.com/api/download/models/${MODEL_ID}?type=Model&format=SafeTensor" \
      -o "$MODEL_NAME" || echo "⚠ Model download failed"
  fi
fi

# -------------------------
# VIDEO MODE WAN LORAS
# -------------------------

if [ "$MODE" = "video" ]; then

  echo "=== Installing WAN Video LoRAs ==="

  if [ -z "${civitai_token:-}" ]; then
    echo "❌ civitai_token not set"
    exit 1
  fi

  cd "$BASE_PATH/loras"

  declare -A LORAS=(
    [2315187]="wan_jiggle_lo"
    [2315167]="wan_jiggle_hi"
    [2073605]="wan_nsfwsks_hi"
    [2083303]="wan_nsfwsks_lo"
  )

  for id in "${!LORAS[@]}"; do
    name="${LORAS[$id]}.safetensors"
    if [ ! -f "$name" ]; then
      echo "⬇ Downloading $name"
      curl -fL \
        -H "Authorization: Bearer ${civitai_token}" \
        "https://civitai.com/api/download/models/${id}?type=Model&format=SafeTensor" \
        -o "$name" || echo "⚠ Failed: $name"
    fi
  done

  echo "✔ WAN LoRAs ready"
fi

# -------------------------
# DRIVE LORA ZIP (IMAGE)
# -------------------------

if [ "$MODE" = "image" ]; then

  echo "Downloading loras.zip from Drive..."

  if rclone copy gdrive:runpod/image/loras.zip /tmp/; then
    unzip -o /tmp/loras.zip -d /tmp/loras_tmp
    mv /tmp/loras_tmp/* "$BASE_PATH/loras/" || true
    rm -rf /tmp/loras_tmp
    rm /tmp/loras.zip
  else
    echo "⚠ No loras.zip found on Drive"
  fi
fi

# -------------------------
# WILDCARDS SYNC
# -------------------------

echo "Syncing wildcards..."

if [ -d "$BASE_PATH/wildcards" ]; then
  rclone sync gdrive:runpod/image/wildcards \
  "$BASE_PATH/wildcards" \
  --include "*.txt" \
  --progress || true
fi

echo "=== BOOTSTRAP COMPLETE ==="
EOF