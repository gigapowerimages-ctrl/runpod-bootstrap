#!/bin/bash
set -euo pipefail

echo "=== RUNPOD BOOTSTRAP START ==="

BASE_PATH="/workspace/ComfyUI/models"
MODE="${MODE:-image}"

echo "Mode: $MODE"

apt update -y
apt install -y unzip wget curl rclone

mkdir -p "$BASE_PATH/diffusion_models"
mkdir -p "$BASE_PATH/loras"
mkdir -p "$BASE_PATH/text_encoders"
mkdir -p "$BASE_PATH/vae"

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
    curl -fL --retry 3 --retry-delay 5 \
      -H "Authorization: Bearer ${civitai_token}" \
      "https://civitai.com/api/download/models/${MODEL_VERSION_ID}?type=Model&format=SafeTensor" \
      -o "$MODEL_NAME"
  fi

  cd "$BASE_PATH/text_encoders"

  if [ ! -f "qwen_2.5_vl_7b_fp8_scaled.safetensors" ]; then
    curl -fL --retry 3 --retry-delay 5 \
      -o qwen_2.5_vl_7b_fp8_scaled.safetensors \
      "https://huggingface.co/Qwen/Qwen2.5-VL-7B-Instruct/resolve/main/qwen_2.5_vl_7b_fp8_scaled.safetensors"
  fi

  cd "$BASE_PATH/vae"

  if [ ! -f "Qwen_Image-VAE.safetensors" ]; then
    curl -fL --retry 3 --retry-delay 5 \
      -o Qwen_Image-VAE.safetensors \
      "https://huggingface.co/Qwen/Qwen-Image/resolve/main/Qwen_Image-VAE.safetensors"
  fi

  cd "$BASE_PATH/loras"

  declare -A QWEN_LORAS=(
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

  for id in "${!QWEN_LORAS[@]}"; do
    name="${QWEN_LORAS[$id]}.safetensors"
    if [ ! -f "$name" ]; then
      curl -fL --retry 3 --retry-delay 5 \
        -H "Authorization: Bearer ${civitai_token}" \
        "https://civitai.com/api/download/models/${id}?type=Model&format=SafeTensor" \
        -o "$name"
    fi
  done

fi

# ---------------- VIDEO MODE ----------------
if [ "$MODE" = "video" ]; then

  if [ -z "${civitai_token:-}" ]; then
    echo "civitai_token not set"
    exit 1
  fi

  cd "$BASE_PATH/loras"

  declare -A WAN_LORAS=(
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

  for id in "${!WAN_LORAS[@]}"; do
    name="${WAN_LORAS[$id]}.safetensors"
    if [ ! -f "$name" ]; then
      curl -fL --retry 3 --retry-delay 5 \
        -H "Authorization: Bearer ${civitai_token}" \
        "https://civitai.com/api/download/models/${id}?type=Model&format=SafeTensor" \
        -o "$name"
    fi
  done

fi


# -------------------------
# CONFIGURE RCLONE
# -------------------------

echo "Configuring rclone..."

if [ -z "${rclone_gdrive_token:-}" ]; then
  echo "ERROR: rclone_gdrive_token not set"
  exit 1
fi

mkdir -p ~/.config/rclone

cat > ~/.config/rclone/rclone.conf <<EOC
[gdrive]
type = drive
scope = drive
token = ${rclone_gdrive_token}
EOC

echo "Testing Drive connection..."

rclone about gdrive: > /dev/null 2>&1 || {
  echo "ERROR: Failed to connect to Google Drive"
  exit 1
}

echo "rclone configured successfully."

# -------------------------
# INSTALL LORAS FROM DRIVE
# -------------------------

echo "Downloading loras.zip from Drive..."

rclone copy gdrive:runpod/image/loras.zip /workspace/ || {
  echo "Failed to download loras.zip"
  exit 1
}

mkdir -p /workspace/ComfyUI/models/loras
unzip -o /workspace/loras.zip -d /workspace/ComfyUI/models/loras
rm /workspace/loras.zip

echo "LoRAs installed."

# -------------------------
# INSTALL WILDCARDS FROM DRIVE
# -------------------------

echo "Downloading wildcards.zip from Drive..."

rclone copy gdrive:runpod/image/wildcards.zip /workspace/ || {
  echo "Failed to download wildcards.zip"
  exit 1
}

mkdir -p /workspace/ComfyUI/models/wildcards
unzip -o /workspace/wildcards.zip \
  -d /workspace/ComfyUI/models/wildcards
rm /workspace/wildcards.zip

echo "Wildcards installed."



# -------------------------
# GOOGLE DRIVE OUTPUT SYNC
# -------------------------

echo "Starting background Google Drive sync..."

mkdir -p /workspace/ComfyUI/output

# Ensure remote folder exists
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
