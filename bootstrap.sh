#!/bin/bash

echo "=== RUNPOD BOOTSTRAP START ==="
set -e

BASE_PATH="/ComfyUI/models"

if [ -z "$MODE" ]; then
  echo " MODE not set. Must be 'image' or 'video'"
  exit 1
fi

echo "Running MODE: $MODE"

apt update -y
apt install -y unzip wget curl git rclone

mkdir -p "$BASE_PATH/loras"

if [ "$MODE" = "video" ]; then
  echo "Setting up VIDEO environment..."

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
      curl -fL -H "Authorization: Bearer ${civitai_token}" `
        "https://civitai.com/api/download/models/${id}" `
        -o "$name"
    fi
  done
fi

echo "=== BOOTSTRAP COMPLETE ==="
