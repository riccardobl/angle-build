#!/bin/bash
set -euo pipefail
mkdir -p build
cp *.gn build/
docker run --rm -it --name=angle-build \
    -v "$(pwd)/build":/root \
    ubuntu \
    bash