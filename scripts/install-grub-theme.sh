#!/usr/bin/env bash
# Stage the Mystical GRUB theme into an image root, or apply it to an installed system.
set -Eeuo pipefail

ROOT=/
SOURCE=
ISO_OUTPUT=
while (($#)); do
  case "$1" in
    --root) ROOT="${2:?Missing root path}"; shift 2 ;;
    --source) SOURCE="${2:?Missing source SVG}"; shift 2 ;;
    --iso-output) ISO_OUTPUT="${2:?Missing ISO output directory}"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--root TARGET_ROOT] [--source BACKGROUND.svg] [--iso-output DIRECTORY]"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

ROOT="$(realpath -m "$ROOT")"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$SOURCE" ]]; then
  SOURCE="$SCRIPT_DIR/../themes/mystical/wallpaper/contents/images/1920x1080.svg"
fi
SOURCE="$(realpath -e "$SOURCE")"
[[ -f "$SOURCE" ]] || { echo "Background SVG not found: $SOURCE" >&2; exit 1; }
command -v rsvg-convert >/dev/null || { echo "Missing rsvg-convert (install librsvg2-bin)." >&2; exit 1; }
command -v grub-mkfont >/dev/null || { echo "Missing grub-mkfont (install grub-common)." >&2; exit 1; }
FONT=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf
[[ -r "$FONT" ]] || { echo "Missing DejaVu Sans font (install fonts-dejavu-core)." >&2; exit 1; }

dest() {
  local relative="${1#/}"
  if [[ "$ROOT" == "/" ]]; then printf '/%s' "$relative"; else printf '%s/%s' "$ROOT" "$relative"; fi
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/mystical"
cp "$SOURCE" "$WORK/mystical/background.svg"
rsvg-convert -w 1920 -h 1080 -o "$WORK/mystical/background.png" "$SOURCE"
grub-mkfont --name="DejaVu Sans" --size=24 --output="$WORK/mystical/title.pf2" "$FONT"
grub-mkfont --name="DejaVu Sans" --size=18 --output="$WORK/mystical/menu.pf2" "$FONT"
cat > "$WORK/mystical/theme.txt" <<'THEME'
title-text: "LYD DEBIAN"
title-font: "DejaVu Sans Regular 24"
title-color: "#F4DEA0"
desktop-image: "background.png"
desktop-color: "#170F22"
terminal-font: "DejaVu Sans Regular 18"
terminal-left: "0"
terminal-top: "0"
terminal-width: "100%"
terminal-height: "100%"

+ boot_menu {
  left = 34%
  top = 40%
  width = 48%
  height = 48%
  item_font = "DejaVu Sans Regular 18"
  item_color = "#D7C8E8"
  selected_item_color = "#FFFFFF"
  item_height = 38
  item_padding = 8
}
THEME

SYSTEM_THEME="$(dest /usr/share/lyd/grub-theme/mystical)"
install -d "$SYSTEM_THEME"
install -m 0644 "$WORK/mystical/"* "$SYSTEM_THEME/"
install -d "$(dest /usr/local/lib/lyd)"
INSTALLER_TARGET="$(dest /usr/local/lib/lyd/install-grub-theme.sh)"
SELF="$(realpath -m "$SCRIPT_DIR/$(basename -- "$0")")"
if [[ "$SELF" != "$(realpath -m "$INSTALLER_TARGET")" ]]; then
  install -m 0755 "$SELF" "$INSTALLER_TARGET"
fi

if [[ -n "$ISO_OUTPUT" ]]; then
  ISO_OUTPUT="$(realpath -m "$ISO_OUTPUT")"
  install -d "$ISO_OUTPUT/lyd-mystical"
  install -m 0644 "$WORK/mystical/"* "$ISO_OUTPUT/lyd-mystical/"
fi

if [[ "$ROOT" == "/" ]]; then
  [[ -x /usr/sbin/update-grub ]] || { echo "update-grub is unavailable; install grub2-common first." >&2; exit 1; }
  [[ -f /etc/default/grub ]] || { echo "/etc/default/grub is missing; GRUB may not be installed." >&2; exit 1; }

  BACKUP="/etc/default/grub.lyd-backup-$(date +%Y%m%d-%H%M%S)"
  cp -a /etc/default/grub "$BACKUP"
  if ! python3 - /etc/default/grub <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
lines = path.read_text().splitlines()
settings = {
    "GRUB_THEME": 'GRUB_THEME="/boot/grub/themes/lyd-mystical/theme.txt"',
    "GRUB_GFXMODE": 'GRUB_GFXMODE="auto"',
    "GRUB_TERMINAL_OUTPUT": 'GRUB_TERMINAL_OUTPUT="gfxterm"',
}
for key, value in settings.items():
    lines = [line for line in lines if not line.startswith(key + "=")]
    lines.append(value)
path.write_text("\n".join(lines) + "\n")
PY
  then
    cp -a "$BACKUP" /etc/default/grub
    exit 1
  fi

  install -d /boot/grub/themes
  rm -rf /boot/grub/themes/lyd-mystical
  cp -a "$SYSTEM_THEME" /boot/grub/themes/lyd-mystical
  if ! update-grub; then
    cp -a "$BACKUP" /etc/default/grub
    update-grub || true
    echo "GRUB configuration failed; restored the previous defaults." >&2
    exit 1
  fi
  echo "Mystical GRUB theme applied. Previous defaults: $BACKUP"
else
  echo "Mystical GRUB theme staged under $ROOT."
fi
