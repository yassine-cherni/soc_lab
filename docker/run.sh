#!/usr/bin/env bash
set -euo pipefail

# Optional overrides (export before running):
#   XILINX_TOOLS_MOUNT  absolute host path for the Vivado install
#                       (default ~/xilinx/tools)
#   VIVADO_HOME_MOUNT   absolute host path for the container user's home
#                       (default ~/xilinx/home)
#   INSTALLER_DIR       host dir with installer and license (default ~/installer)
#
# Both mounts default to plain host folders so the install survives container
# deletion, image rebuilds, and Docker cleanups (docker volume prune, etc.).
# A value that does not start with "/" is treated as a named Docker volume;
# that works, but those volumes live inside Docker's data directory and can be
# deleted by Docker commands.

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
HOST_USER="$(id -un)"

IMAGE="vivado-base:24.04"
XILINX_TOOLS_MOUNT="${XILINX_TOOLS_MOUNT:-$HOME/xilinx/tools}"
VIVADO_HOME_MOUNT="${VIVADO_HOME_MOUNT:-$HOME/xilinx/home}"
INSTALLER_DIR="${INSTALLER_DIR:-$HOME/installer}"

: "${DISPLAY:?Run this script from a graphical desktop session with DISPLAY set}"

if [[ ! -d "$INSTALLER_DIR" ]]; then
    echo "Error: $INSTALLER_DIR does not exist." >&2
    exit 1
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "Error: image $IMAGE not found. Build it first (docs/03-docker-environment.md)." >&2
    exit 1
fi

# A mount that starts with "/" is a host directory: create it and warn if the
# container user (same UID as you) could not write to it. Anything else is a
# named Docker volume, which Docker initialises with the image's ownership.
prepare_mount() {
    local target="$1"
    [[ "$target" == /* ]] || return 0
    mkdir -p "$target"
    if [[ "$(stat -c %u "$target")" != "$(id -u)" ]]; then
        echo "Warning: $target is not owned by UID $(id -u)." >&2
        echo "         Fix with: sudo chown -R \"$(id -u):$(id -g)\" \"$target\"" >&2
    fi
}
prepare_mount "$XILINX_TOOLS_MOUNT"
prepare_mount "$VIVADO_HOME_MOUNT"

xhost "+SI:localuser:${HOST_USER}" >/dev/null

cleanup() {
    xhost "-SI:localuser:${HOST_USER}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

SERIAL_ARGS=()
shopt -s nullglob

for device in /dev/ttyUSB* /dev/ttyACM*; do
    SERIAL_ARGS+=(--device "$device")
done

shopt -u nullglob

docker run -it --rm --name vivado \
    --network=host \
    --device-cgroup-rule='c 189:* rmw' \
    --device-cgroup-rule='c 188:* rmw' \
    -e DISPLAY="$DISPLAY" \
    -e QT_X11_NO_MITSHM=1 \
    -e _JAVA_AWT_WM_NONREPARENTING=1 \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v /dev/bus/usb:/dev/bus/usb \
    "${SERIAL_ARGS[@]}" \
    -v "$INSTALLER_DIR:/installer" \
    -v "$REPO:/work" \
    -v "${XILINX_TOOLS_MOUNT}:/tools/Xilinx" \
    -v "${VIVADO_HOME_MOUNT}:/home/vivado" \
    "$IMAGE" "$@"