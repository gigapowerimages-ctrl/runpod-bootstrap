#!/bin/bash

echo "=== RUNPOD BOOTSTRAP START ==="
set -e

BASE_PATH="/workspace/ComfyUI/models"
WILDCARD_PATH="$BASE_PATH/wildcards"
MODE="${MODE}"

if [ -z "$MODE" ]; then
  echo "❌ MODE not set. Must be 'image' or 'video'"
  exit 1
fi

apt update -y
apt install -y unzip wget curl git rclone

mkdir -p $BASE_PATH/diffusion_models
mkdir -p $BASE_PATH/loras
mkdir -p $BASE_PATH/text_encoders
mkdir -p $BASE_PATH/vae
mkdir -p $WILDCARD_PATH
mkdir -p /workspace/tmp

# =====================================================
# RCLONE SETUP
# =====================================================

mkdir -p ~/.config/rclone

cat > ~/.config/rclone/rclone.conf <<EOF
[gdrive]
type = drive
scope = drive
token = ${rclone_gdrive_token}
EOF

echo "Testing Drive connection..."
rclone about gdrive: || { echo "❌ Drive auth failed"; exit 1; }

echo "Running MODE: $MODE"

# =====================================================
# IMAGE MODE
# =====================================================

if [ "$MODE" = "image" ]; then

  echo "Setting up IMAGE environment..."

  # -------------------------
  # QWEN BASE MODEL
  # -------------------------

  cd $BASE_PATH/diffusion_models
  MODEL_VERSION_ID=2086298
  MODEL_NAME="qwen_image_model.safetensors"

  if [ ! -f "$MODEL_NAME" ]; then
    curl -fL -H "Authorization: Bearer ${civitai_token}" \
      "https://civitai.com/api/download/models/${MODEL_VERSION_ID}?type=Model&format=SafeTensor" \
      -o "$MODEL_NAME"
  fi

  # -------------------------
  # TEXT ENCODER
  # -------------------------

  cd $BASE_PATH/text_encoders
  if [ ! -f "qwen_2.5_vl_7b_fp8_scaled.safetensors" ]; then
    curl -L -o qwen_2.5_vl_7b_fp8_scaled.safetensors \
      "https://huggingface.co/Qwen/Qwen2.5-VL-7B-Instruct/resolve/main/qwen_2.5_vl_7b_fp8_scaled.safetensors"
  fi

  # -------------------------
  # VAE
  # -------------------------

  cd $BASE_PATH/vae
  if [ ! -f "Qwen_Image-VAE.safetensors" ]; then
    curl -L -o Qwen_Image-VAE.safetensors \
      "https://huggingface.co/Qwen/Qwen-Image/resolve/main/Qwen_Image-VAE.safetensors"
  fi

  # -------------------------
  # QWEN LORAS
  # -------------------------

  cd $BASE_PATH/loras

  declare -A LORAS=(
    [2106185]="qwen_lenovo"
    [2338807]="qwen_analog"
    [2108245]="qwen_adorable"
    [2436841]="qwen_coolshot"
    [2207719]="qwen_filmstill"
    [2270374]="qwen_samsung"
    [2233198]="qwen_SNOFS"
    [2195978]="qwen_MYSTIC"
    [2316696]="qwen_4PLAY"
  )

  for id in "${!LORAS[@]}"; do
    name="${LORAS[$id]}.safetensors"
    if [ ! -f "$name" ]; then
      echo "Downloading $name..."
      curl -fL -H "Authorization: Bearer ${civitai_token}" \
        "https://civitai.com/api/download/models/${id}?type=Model&format=SafeTensor" \
        -o "$name"
    fi
  done

  # -------------------------
  # INSTALL GPROMPTS
  # -------------------------

  cd /workspace/ComfyUI/custom_nodes
  if [ ! -d "comfyui_gprompts" ]; then
    git clone https://github.com/GadzoinksOfficial/comfyui_gprompts.git
  fi

fi

# =====================================================
# VIDEO MODE
# =====================================================

if [ "$MODE" = "video" ]; then

  echo "Setting up VIDEO environment..."

  cd $BASE_PATH/loras

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
      echo "Downloading $name..."
      curl -fL -H "Authorization: Bearer ${civitai_token}" \
        "https://civitai.com/api/download/models/${id}?type=Model&format=SafeTensor" \
        -o "$name"
    fi
  done

fi

# =====================================================
# SAFE OUTPUT AUTO UPLOAD
# =====================================================

echo "Starting output auto-upload..."

mkdir -p /workspace/ComfyUI/output
rclone mkdir gdrive:ComfyUI-Outputs/${MODE} 2>/dev/null || true

nohup bash -c "
while true; do
  rclone copy /workspace/ComfyUI/output gdrive:ComfyUI-Outputs/${MODE} \
    --ignore-existing \
    --transfers 4 \
    --checkers 4 \
    --fast-list
  sleep 60
done
" > /workspace/rclone.log 2>&1 &

echo "=== BOOTSTRAP COMPLETE ==="