#!/bin/bash
set -e

echo "==============================="
echo " RUNPOD SETUP SCRIPT STARTED "
echo "==============================="

echo ""
echo "Current working directory:"
pwd

echo ""
echo "Root directory:"
ls -lah /

echo ""
echo "Check if ComfyUI exists:"
ls -lah /ComfyUI || echo "No /ComfyUI directory"

echo ""
echo "Check models directory:"
ls -lah /ComfyUI/models || echo "No models directory"

echo ""
echo "Check if workspace mounted:"
ls -lah /workspace || echo "No workspace mount"

echo ""
echo "Environment variables:"
echo "MODE=$MODE"
echo "civitai_token length: ${#civitai_token}"

echo ""
echo "==============================="
echo " SETUP SCRIPT FINISHED "
echo "==============================="
