#!/bin/bash
set -euo pipefail

echo "=== RUNPOD BOOTSTRAP START ==="

MODE="${MODE:-image}"
BASE_PATH="/workspace/ComfyUI/models"
COMFY_ROOT="/workspace/ComfyUI"

echo "Mode: $MODE"

# -------------------------
# BASIC PACKAGES
# -------------------------

apt update -y
apt install -y unzip wget curl rclone git

# -------------------------

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

if [ ! -f "qwen_image_vae.safetensors" ]; then
  wget -q --show-progress -O qwen_image_vae.safetensors \
  https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors
else
  echo "✔ Qwen VAE exists"
fi

# -------------------------
# QWEN TEXT ENCODER
# -------------------------

echo "Installing Qwen Text Encoder..."

cd "$BASE_PATH/text_encoders"

if [ ! -f "qwen_2.5_vl_7b_fp8_scaled.safetensors" ]; then
  wget -q --show-progress -O qwen_2.5_vl_7b_fp8_scaled.safetensors \
  https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors
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

  echo "=== Installing Image Mode CivitAI LoRAs ==="

  cd "$BASE_PATH/loras"

  declare -A IMAGE_LORAS=(
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

  for id in "${!IMAGE_LORAS[@]}"; do
    name="${IMAGE_LORAS[$id]}.safetensors"
    if [ ! -f "$name" ]; then
      echo "Downloading $name"
      curl -fL \
        -H "Authorization: Bearer ${civitai_token}" \
        "https://civitai.com/api/download/models/${id}?type=Model&format=SafeTensor" \
        -o "$name" || echo "Failed: $name"
    else
      echo "$name exists"
    fi
  done
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

      [2484657]="wan_k3nk_hi"
      [2538990]="wan_k3nk_lo"

      [2370687]="wan_bbc_bj_hi"
      [2370744]="wan_bbc_bj_lo"

      [2553271]="wan_dr34ml4y_lo"
      [2553151]="wan_dr34ml4y_hi"
      
      [2209354]="wan_bounce_hi"
      [2209344]="wan_bounce_lo"
      
      [2246669]="wan_ripple_hi"
      [2246694]="wan_ripple_lo"

      [2273468]="wan_slop_hi"
      [2273467]="wan_slop_lo"

      [2235299]="wan_2xbj_hi"
      [2235288]="wan_2xbj_lo"

      [2546793]="wan_struts_hi"
      [2546797]="wan_struts_lo"

      [2195559]="wan_deep_hi"
      [2195625]="wan_deep_lo"

      [2663475]="wan_press_hi"
      [2663487]="wan_press_lo"

      [2419370]="wan_ahe_hi"
      [2419374]="wan_ahe_lo"

      [2510280]="wan_move_hi"
      [2510218]="wan_move_lo"

      [2648813]="wan_ride_hi"
      [2648814]="wan_ride_lo"

      [2508498]="wan_twk_hi"
      [2514311]="wan_twk_lo"

      [2517513]="wan_deepface_hi"
      [2517548]="wan_deepface_lo"
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
