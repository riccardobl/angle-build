#!/bin/bash
set -euo pipefail

IMAGE="registry.gitlab.steamos.cloud/steamrt/sniper/sdk"
CONTAINER_NAME="angle-build"

podman run --rm -it --name="$CONTAINER_NAME" \
    -v "$(pwd)":/workspace:z \
    -w /workspace \
    "$IMAGE" \
    bash -lc '
set -euo pipefail

git clone --depth=1 https://chromium.googlesource.com/chromium/tools/depot_tools.git /tmp/depot_tools
export PATH="/tmp/depot_tools:$PATH"

rm -rf angle
mkdir -p angle
cd angle

fetch angle

ANGLE_COMMIT="$(git rev-parse HEAD)"
RUNNER_OS="Linux"
ANGLE_DEBUG="${ANGLE_DEBUG:-true}"

if git apply --reverse --check ../patches/0001-linux-prefer-vulkan-default-display.patch; then
    :
elif git apply --check ../patches/0001-linux-prefer-vulkan-default-display.patch; then
    git apply ../patches/0001-linux-prefer-vulkan-default-display.patch
else
    echo "Patch ../patches/0001-linux-prefer-vulkan-default-display.patch does not apply cleanly" >&2
    exit 1
fi

rm -rf ../angle-artifacts/natives-linux ../angle-artifacts/natives-linux-arm64

targets=(
    "natives-linux|linux|x86_64|x64|../release-linux-x64.gn"
    "natives-linux-arm64|linux|arm64|arm64|../release-linux-arm64.gn"
)

for target in "${targets[@]}"; do
    IFS="|" read -r classifier runtime_os_dir arch_dir target_cpu args_file <<< "$target"
    target_name="$(basename "$args_file" .gn)"
    out_dir="out/${target_name}"
    out_stage="../angle-artifacts/${classifier}/native/angle/${runtime_os_dir}/${arch_dir}"

    mkdir -p "$out_dir"
    cp "$args_file" "$out_dir/args.gn"

    if [[ "$target_cpu" == "arm64" ]]; then
        python3 build/linux/sysroot_scripts/install-sysroot.py --arch=arm64
    fi

    gn gen "$out_dir"
    autoninja -C "$out_dir" libEGL libGLESv2

    mkdir -p "$out_stage"
    printf "ANGLE_COMMIT=%s\nRUNNER_OS=%s\nTARGET_CPU=%s\nANGLE_DEBUG=%s\n" \
        "$ANGLE_COMMIT" "$RUNNER_OS" "$target_cpu" "$ANGLE_DEBUG" > "$out_stage/ANGLE_BUILD_INFO.txt"

    cp -f LICENSE "$out_stage/LICENSE.ANGLE" || true
    cp -f "$out_dir"/libEGL.* "$out_stage/"
    cp -f "$out_dir"/libGLESv2.* "$out_stage/"
    rm -f "$out_stage/"*.TOC || true
done
'
