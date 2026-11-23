#!/usr/bin/env bash
# Compile the pinned KDE Aurorae source against Debian Trixie's KDE/Qt stack.
# The actual runtime plugin is already shipped by Debian's kwin-common package;
# do not create a second package that attempts to overwrite that plugin.
set -Eeuo pipefail

readonly AURORAE_COMMIT="900090a548eee8c7b81b8f52702e0c27236c9322"
readonly AURORAE_VERSION="6.3.80"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lyd-aurorae.XXXXXX")"
trap 'rm -rf -- "$WORK_DIR"' EXIT
SOURCE_DIR="$WORK_DIR/source"
BUILD_DIR="$WORK_DIR/build"
STAGE_DIR="$WORK_DIR/stage"

for tool in git cmake ninja; do
  command -v "$tool" >/dev/null || {
    echo "Missing build tool: $tool" >&2
    echo "Install the Aurorae build dependencies listed in .github/workflows/build-iso.yml." >&2
    exit 1
  }
done

echo "Fetching KDE Aurorae $AURORAE_VERSION source at pinned commit $AURORAE_COMMIT"
git init -q "$SOURCE_DIR"
git -C "$SOURCE_DIR" remote add origin https://github.com/KDE/aurorae.git
git -C "$SOURCE_DIR" fetch --depth=1 origin "$AURORAE_COMMIT"
git -C "$SOURCE_DIR" checkout --quiet --detach FETCH_HEAD

grep -q 'set(PROJECT_VERSION "6.3.80")' "$SOURCE_DIR/CMakeLists.txt" || {
  echo "Pinned Aurorae source does not match expected version $AURORAE_VERSION." >&2
  exit 1
}

echo "Configuring Aurorae against Debian Trixie's installed KDE/Qt libraries"
cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DBUILD_TESTING=OFF
cmake --build "$BUILD_DIR" --parallel "$(nproc)"
DESTDIR="$STAGE_DIR" cmake --install "$BUILD_DIR"

PLUGIN="$(find "$STAGE_DIR" -type f -path '*/org.kde.kdecoration3/org.kde.kwin.aurorae.so' -print -quit)"
[[ -n "$PLUGIN" ]] || {
  echo "Aurorae build did not produce the expected KDecoration3 plugin." >&2
  find "$STAGE_DIR" -type f -print >&2
  exit 1
}

echo "Aurorae source build succeeded: $PLUGIN"
echo "The live image uses Debian's kwin-common-owned Aurorae plugin to avoid file conflicts."
