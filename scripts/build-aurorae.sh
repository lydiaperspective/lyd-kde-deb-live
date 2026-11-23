#!/usr/bin/env bash
# Build a Trixie-compatible Aurorae KWin decoration engine from KDE source.
set -Eeuo pipefail

readonly AURORAE_COMMIT="900090a548eee8c7b81b8f52702e0c27236c9322"
readonly AURORAE_VERSION="6.3.80+git20250310"
OUTPUT_DIR=""

while (($#)); do
  case "$1" in
    --output-dir) OUTPUT_DIR="${2:?Missing output directory}"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 --output-dir DIRECTORY"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$OUTPUT_DIR" ]] || { echo "--output-dir is required." >&2; exit 2; }
for tool in git cmake ninja dpkg-deb dpkg-shlibdeps dpkg-query; do
  command -v "$tool" >/dev/null || {
    echo "Missing build tool: $tool" >&2
    exit 1
  }
done

OUTPUT_DIR="$(realpath -m "$OUTPUT_DIR")"
mkdir -p "$OUTPUT_DIR"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/lyd-aurorae.XXXXXX")"
trap 'rm -rf -- "$WORK_DIR"' EXIT
SOURCE_DIR="$WORK_DIR/source"
BUILD_DIR="$WORK_DIR/build"
PACKAGE_ROOT="$WORK_DIR/package"

echo "Fetching KDE Aurorae source at pinned commit $AURORAE_COMMIT"
git init -q "$SOURCE_DIR"
git -C "$SOURCE_DIR" remote add origin https://github.com/KDE/aurorae.git
git -C "$SOURCE_DIR" fetch --depth=1 origin "$AURORAE_COMMIT"
git -C "$SOURCE_DIR" checkout --quiet --detach FETCH_HEAD

grep -q 'set(PROJECT_VERSION "6.3.80")' "$SOURCE_DIR/CMakeLists.txt" || {
  echo "Pinned Aurorae source does not match the expected compatible source version." >&2
  exit 1
}

echo "Configuring Aurorae against the installed Debian Trixie KDE/Qt libraries"
cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DBUILD_TESTING=OFF
cmake --build "$BUILD_DIR" --parallel "$(nproc)"
DESTDIR="$PACKAGE_ROOT" cmake --install "$BUILD_DIR"

mapfile -d '' PLUGINS < <(find "$PACKAGE_ROOT" -type f -name '*.so' -print0)
(("${#PLUGINS[@]}" > 0)) || {
  echo "Aurorae build did not install any shared plugin modules." >&2
  exit 1
}
find "$PACKAGE_ROOT" -type f -path '*/org.kde.kdecoration3/*.so' | grep -q . || {
  echo "Aurorae KDecoration3 plugin was not installed in the expected plugin directory." >&2
  exit 1
}

# Derive runtime library dependencies from the compiled modules.
mkdir -p "$WORK_DIR/debian"
cat > "$WORK_DIR/debian/control" <<'CONTROL'
Source: lyd-aurorae
Section: kde
Priority: optional
Maintainer: Lyd Ark Build <noreply@example.invalid>
Standards-Version: 4.7.0

Package: lyd-aurorae
Architecture: any
Description: Aurorae SVG window decoration engine for KDE Plasma
 Themeable SVG-based KWin window decoration engine, built from KDE source
 for the Debian Trixie KDE Frameworks and Qt stack.
CONTROL
(
  cd "$WORK_DIR"
  dpkg-shlibdeps -O "${PLUGINS[@]}" > "$WORK_DIR/shlibdeps"
)
RUNTIME_DEPS="$(sed -n 's/^shlibs:Depends=//p' "$WORK_DIR/shlibdeps" | head -n1)"
[[ -n "$RUNTIME_DEPS" ]] || {
  echo "dpkg-shlibdeps did not produce runtime dependencies." >&2
  cat "$WORK_DIR/shlibdeps" >&2
  exit 1
}

install -d "$PACKAGE_ROOT/DEBIAN"
cat > "$PACKAGE_ROOT/DEBIAN/control" <<CONTROL
Package: lyd-aurorae
Version: ${AURORAE_VERSION}-1
Section: kde
Priority: optional
Architecture: $(dpkg --print-architecture)
Depends: ${RUNTIME_DEPS}, kwin-wayland | kwin-x11
Maintainer: Lyd Ark Build <noreply@example.invalid>
Description: Aurorae SVG window decoration engine for KDE Plasma
 Themeable SVG-based KWin window decoration engine, built from KDE source
 for the Debian Trixie KDE Frameworks and Qt stack.
CONTROL

PACKAGE="$OUTPUT_DIR/lyd-aurorae_${AURORAE_VERSION}-1_$(dpkg --print-architecture).deb"
rm -f "$OUTPUT_DIR"/lyd-aurorae_*.deb
dpkg-deb --build --root-owner-group "$PACKAGE_ROOT" "$PACKAGE" >/dev/null
dpkg-deb --info "$PACKAGE"
echo "Aurorae package created: $PACKAGE"
