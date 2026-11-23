#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${1:-}"

case "$PROFILE" in
  desktop|server) ;;
  *)
    echo "Usage: $0 {desktop|server}" >&2
    exit 2
    ;;
esac

PROFILE_DIR="$ROOT_DIR/profiles/$PROFILE"
if [[ ! -f "$PROFILE_DIR/auto/config" ]]; then
  echo "Missing live-build configuration: $PROFILE_DIR/auto/config" >&2
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  exec sudo -- "$0" "$PROFILE"
fi

command -v lb >/dev/null || {
  echo "live-build (lb) is not installed. Install it with: sudo apt install live-build" >&2
  exit 1
}

mkdir -p "$PROFILE_DIR/config/includes.chroot/usr/local/sbin"
install -m 0755 "$ROOT_DIR/scripts/lydsys" \
  "$PROFILE_DIR/config/includes.chroot/usr/local/sbin/lydsys"

cd "$PROFILE_DIR"
export LB_CONFIG_OPTIONS=""
lb clean --purge
lb config
lb build

ISO="$(find "$PROFILE_DIR" -maxdepth 1 -type f -name '*.iso' -printf '%T@ %p\n' | sort -nr | head -n1 | cut -d' ' -f2-)"
if [[ -z "$ISO" ]]; then
  echo "Build completed but no ISO was found in $PROFILE_DIR" >&2
  exit 1
fi

sha256sum "$ISO" > "$ISO.sha256"
echo "Build complete: $ISO"
