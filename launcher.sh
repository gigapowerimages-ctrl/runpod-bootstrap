#!/bin/bash
set -e

cd /workspace

if [ ! -d runpod-bootstrap ]; then
  git clone https://github.com/gigapowerimages-ctrl/runpod-bootstrap.git
fi

cd runpod-bootstrap
git pull

MODE=${MODE:-image} bash bootstrap.sh