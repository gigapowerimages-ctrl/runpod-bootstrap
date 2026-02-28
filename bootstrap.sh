#!/bin/bash
set -euo pipefail

echo "=== RUNPOD BOOTSTRAP START ==="

# -------------------------
# SET MODE (image or video)
# -------------------------

MODE="${MODE:-image}"
echo "Mode: $MODE"

echo "Detecting ComfyUI location..."

if [ -d "/workspace/runpod-slim/ComfyUI/models" ]; then
    COMFY_ROOT="/workspace/runpod-slim/ComfyUI"

elif [ -d "/workspace/ComfyUI/models" ]; then
    COMFY_ROOT="/workspace/ComfyUI"

elif [ -d "/ComfyUI/models" ]; then
    COMFY_ROOT="/ComfyUI"

else
    echo "❌ Could not find ComfyUI models folder"
    exit 1
fi

echo "Using ComfyUI at: $COMFY_ROOT"

BASE_PATH="$COMFY_ROOT/models"
mkdir -p "$BASE_PATH/diffusion_models"
mkdir -p "$BASE_PATH/vae"
mkdir -p "$BASE_PATH/text_encoders"
mkdir -p "$BASE_PATH/loras"
mkdir -p "$BASE_PATH/wildcards"

echo "Using ComfyUI at: $COMFY_ROOT"
echo "Models path: $BASE_PATH"

# -------------------------
# BASIC PACKAGES
# -------------------------

if ! command -v rclone >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y -qq unzip wget curl rclone git
fi

# -------------------------
# RCLONE CONFIG
# -------------------------

echo "Configuring rclone..."

if [ -n "${rclone_gdrive_token:-}" ]; then
    TOKEN="$rclone_gdrive_token"
elif [ -n "${gdrive_runpod_root:-}" ]; then
    TOKEN="$gdrive_runpod_root"
else
    echo "❌ No Google Drive token provided"
    exit 1
fi

mkdir -p ~/.config/rclone

printf "[gdrive]\ntype = drive\nscope = drive\ntoken = %s\n" \
"$TOKEN" > ~/.config/rclone/rclone.conf

if ! rclone about gdrive: > /dev/null 2>&1; then
    echo "❌ Failed to connect to Google Drive"
    exit 1
fi

echo "✔ rclone configured"

# -------------------------
# IMAGE MODE
# -------------------------

if [ "$MODE" = "image" ]; then

  # Install custom node
  echo "=== Installing comfyui_gprompts ==="
  if [ -d "$COMFY_ROOT/custom_nodes" ]; then
      cd "$COMFY_ROOT/custom_nodes"
      if [ ! -d "comfyui_gprompts" ]; then
          git clone https://github.com/GadzoinksOfficial/comfyui_gprompts.git
          echo "✔ comfyui_gprompts installed"
      else
          echo "✔ comfyui_gprompts already exists"
      fi
  else
      echo "⚠ custom_nodes folder not found"
  fi

  # -------------------------
  # QWEN BASE MODEL
  # -------------------------

  echo "Installing Qwen Base Model..."
  cd "$BASE_PATH/diffusion_models"
  if [ ! -f "qwen_image_fp8_e4m3fn.safetensors" ]; then
    wget -q --show-progress -O qwen_image_fp8_e4m3fn.safetensors \
    https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_fp8_e4m3fn.safetensors \
    || echo "⚠ Qwen model download failed"
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
    https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors \
    || echo "⚠ VAE download failed"
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
    https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors \
    || echo "⚠ Text encoder download failed"
  else
    echo "✔ Qwen Text Encoder exists"
  fi

  # -------------------------
  # IMAGE LORAS
  # -------------------------

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
      curl -fL \
        -H "Authorization: Bearer ${civitai_token}" \
        "https://civitai.com/api/download/models/${id}?type=Model&format=SafeTensor" \
        -o "$name" || echo "⚠ Failed: $name"
    else
      echo "$name exists"
    fi

  done

# -------------------------
# DRIVE ZIP (Smart Skip)
# -------------------------

if [ -z "$(ls -A "$BASE_PATH/loras" 2>/dev/null)" ]; then
    echo "LoRA folder empty — downloading loras.zip..."

    rclone copy gdrive:runpod/image/loras.zip /tmp/

    unzip -o /tmp/loras.zip -d /tmp/loras_tmp
    find /tmp/loras_tmp -type f -name "*.safetensors" -exec mv {} "$BASE_PATH/loras/" \;

    rm -rf /tmp/loras_tmp
    rm /tmp/loras.zip
else
    echo "LoRA folder not empty — skipping zip download"
fi
fi   # closes IMAGE mode

# -------------------------
# WILDCARDS SYNC
# -------------------------

echo "Syncing wildcards..."
rclone sync gdrive:runpod/image/wildcards \
  "$BASE_PATH/wildcards" \
  --include "*.txt" \
  --progress

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
# WORKFLOW SYNC (Named Only)
# -------------------------

echo "Syncing workflow for $MODE mode..."

WORKFLOW_DIR="$COMFY_ROOT/user/default/workflows"
mkdir -p "$WORKFLOW_DIR"

if [ "$MODE" = "image" ]; then
    rclone copy gdrive:runpod/image/image.json "$WORKFLOW_DIR/"
fi

if [ "$MODE" = "video" ]; then
    rclone copy gdrive:runpod/video/video.json "$WORKFLOW_DIR/"
fi

# -------------------------
# AUTO SYNC OUTPUTS TO DRIVE
# -------------------------

OUTPUT_DIR="$COMFY_ROOT/output"

if [ "$MODE" = "image" ]; then
    DRIVE_TARGET="gdrive:runpod/image/output"
elif [ "$MODE" = "video" ]; then
    DRIVE_TARGET="gdrive:runpod/video/output"
fi

if [ -n "${DRIVE_TARGET:-}" ]; then
    mkdir -p "$OUTPUT_DIR"
    (
    while true; do
        rclone copy "$OUTPUT_DIR" "$DRIVE_TARGET" --ignore-existing --transfers 4 --checkers 8
        sleep 30
    done
    ) &
    echo "Drive auto-sync running."
fi

echo "=== BOOTSTRAP COMPLETE ==="