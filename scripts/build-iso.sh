#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${1:-}"

case "$PROFILE" in
  desktop|server) ;;
  *)
    echo "Usage: bash scripts/build-iso.sh {desktop|server}" >&2
    exit 2
    ;;
esac

PROFILE_DIR="$ROOT_DIR/profiles/$PROFILE"
if [[ ! -f "$PROFILE_DIR/auto/config" ]]; then
  echo "Missing live-build configuration: $PROFILE_DIR/auto/config" >&2
  exit 1
fi

if [[ $EUID -ne 0 ]]; then
  exec sudo -- bash "$ROOT_DIR/scripts/build-iso.sh" "$PROFILE"
fi

command -v lb >/dev/null || {
  echo "live-build (lb) is not installed. Install it with: sudo apt install live-build" >&2
  exit 1
}

mkdir -p "$PROFILE_DIR/config/includes.chroot/usr/local/sbin"
install -m 0755 "$ROOT_DIR/scripts/lydsys" \
  "$PROFILE_DIR/config/includes.chroot/usr/local/sbin/lydsys"
install -m 0755 "$ROOT_DIR/scripts/lydsetup" \
  "$PROFILE_DIR/config/includes.chroot/usr/local/bin/lydsetup"
install -m 0755 "$ROOT_DIR/scripts/lydhelp" \
  "$PROFILE_DIR/config/includes.chroot/usr/local/bin/lydhelp"
install -m 0755 "$ROOT_DIR/scripts/lyd-btrfs-postinstall" \
  "$PROFILE_DIR/config/includes.chroot/usr/local/sbin/lyd-btrfs-postinstall"

bash "$ROOT_DIR/scripts/install-grub-theme.sh" \
  --root "$PROFILE_DIR/config/includes.chroot" \
  --source "$ROOT_DIR/themes/mystical/wallpaper/contents/images/1920x1080.svg" \
  --iso-output "$PROFILE_DIR/config/includes.binary/boot/grub/themes"
install -D -m 0755 "$ROOT_DIR/scripts/9999-grub-theme.hook.binary" \
  "$PROFILE_DIR/config/hooks/live/9999-grub-theme.hook.binary"

if [[ "$PROFILE" == "desktop" ]]; then
  bash "$ROOT_DIR/scripts/install-mystical-theme.sh" \
    --root "$PROFILE_DIR/config/includes.chroot" \
    --source "$ROOT_DIR/themes/mystical"
fi

cd "$PROFILE_DIR"
chmod +x auto/config
lb clean --purge
lb config
lb build

SOURCE_ISO="$(find "$PROFILE_DIR" -maxdepth 1 -type f -name '*.iso' -printf '%T@ %p\n' | sort -nr | head -n1 | cut -d' ' -f2-)"
if [[ -z "$SOURCE_ISO" ]]; then
  echo "Build completed but no ISO was found in $PROFILE_DIR" >&2
  exit 1
fi

ISO="$PROFILE_DIR/lyd-debian-$PROFILE-amd64.iso"
mv -- "$SOURCE_ISO" "$ISO"
sha256sum "$ISO" > "$ISO.sha256"
echo "Build complete: $ISO"
