#!/usr/bin/env bash
# Local dev build for the tuned fork on the owner's Linux PC.
#
# Usage:
#   tools/local/build.sh [--reconfigure] [extra cmake -D flags...]
#
# Incremental build in build/local with ccache. Mirrors the Linux flags of
# .github/workflows/release-binaries.yml, minus CI-only bits; the update
# checker is off so a local build never chases upstream release tags.
# PGO is not built locally; release packages come from GitHub Actions.
set -euo pipefail
cd "$(dirname "$0")/../.."

BUILD_DIR="${LICHII_BUILD_DIR:-build/local}"
JOBS="${LICHII_JOBS:-6}"
BUILD_TYPE="${LICHII_BUILD_TYPE:-Release}"

for tool in cmake ninja; do
  if ! command -v "$tool" > /dev/null; then
    echo "missing tool: $tool — install the dependencies in docs/Deps.md first" >&2
    exit 1
  fi
done
if ! command -v ccache > /dev/null; then
  echo "warning: ccache not found, rebuilds will be much slower" >&2
fi

flags=(
  "-DCMAKE_BUILD_TYPE=$BUILD_TYPE"
  -DBUILD_TESTING=OFF
  -DYUZU_TESTS=OFF
  -DYUZU_CMD=ON
  -DYUZU_ROOM=OFF
  -DYUZU_ROOM_STANDALONE=OFF
  -DYUZU_USE_BUNDLED_QT=OFF
  -DYUZU_USE_BUNDLED_SDL3=ON
  -DVulkanHeaders_FORCE_BUNDLED=ON
  -DVulkanUtilityLibraries_FORCE_BUNDLED=ON
  -DENABLE_UPDATE_CHECKER=OFF
  -DLICHII_BUILD_TAG=local
  -DUSE_DISCORD_PRESENCE=OFF
  -DUSE_CCACHE=ON
)
# Optional Qt 6.8.x install (CI uses 6.8.3). System Qt 6 needs no prefix path.
if [ -n "${QT_PREFIX:-}" ]; then
  flags+=("-DCMAKE_PREFIX_PATH=$QT_PREFIX")
elif [ -d "$HOME/Qt/6.8.3/gcc_64" ]; then
  flags+=("-DCMAKE_PREFIX_PATH=$HOME/Qt/6.8.3/gcc_64")
fi

reconfigure=0
extra=()
for arg in "$@"; do
  if [ "$arg" = "--reconfigure" ]; then reconfigure=1; else extra+=("$arg"); fi
done

if [ "$reconfigure" = 1 ] || [ ! -f "$BUILD_DIR/build.ninja" ]; then
  cmake -S . -B "$BUILD_DIR" -G Ninja "${flags[@]}" "${extra[@]}"
fi

status=0
cmake --build "$BUILD_DIR" --target yuzu yuzu-cmd --parallel "$JOBS" || status=$?
if [ "$status" != 0 ]; then
  echo "build failed. If the link step was killed, memory ran out:" >&2
  echo "retry with LICHII_JOBS=3 tools/local/build.sh" >&2
  exit "$status"
fi

echo "built: $BUILD_DIR/bin/yuzu (frontend), $BUILD_DIR/bin/yuzu-cmd (CLI)"
echo "play with the agent debug server on: tools/local/play.sh"
