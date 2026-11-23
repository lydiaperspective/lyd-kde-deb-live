#!/usr/bin/env bash
# Install the Lyd Ark Mystical KDE theme into a target root (or the running OS).
set -Eeuo pipefail

ROOT=/
SOURCE=
while (($#)); do
  case "$1" in
    --root) ROOT="${2:?Missing root path}"; shift 2 ;;
    --source) SOURCE="${2:?Missing theme source path}"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--root TARGET_ROOT] [--source THEME_SOURCE]"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

ROOT="$(realpath -m "$ROOT")"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$SOURCE" ]]; then
  if [[ -d "$SCRIPT_DIR/../themes/mystical" ]]; then
    SOURCE="$SCRIPT_DIR/../themes/mystical"
  elif [[ -d /usr/share/lyd/themes/mystical ]]; then
    SOURCE=/usr/share/lyd/themes/mystical
  else
    echo "Cannot locate themes/mystical. Pass --source." >&2
    exit 1
  fi
fi
SOURCE="$(realpath -e "$SOURCE")"
[[ -d "$SOURCE" ]] || { echo "Theme source not found: $SOURCE" >&2; exit 1; }

dest() {
  local relative="${1#/}"
  if [[ "$ROOT" == "/" ]]; then
    printf '/ %s' "$relative" | tr -d ' '
  else
    printf '%s/%s' "$ROOT" "$relative"
  fi
}
install -d "$(dest /usr/share/color-schemes)"
install -m 0644 "$SOURCE/colors/Mystical.colors" "$(dest /usr/share/color-schemes/Mystical.colors)"

copy_tree() {
  local source_path="$1" target_path="$2"
  install -d "$(dirname -- "$(dest "$target_path")")"
  rm -rf -- "$(dest "$target_path")"
  cp -a "$source_path" "$(dest "$target_path")"
}

copy_tree "$SOURCE/look-and-feel/org.lydark.mystical.desktop" \
  /usr/share/plasma/look-and-feel/org.lydark.mystical.desktop
copy_tree "$SOURCE/plasma-style/org.lydark.mystical.desktop" \
  /usr/share/plasma/desktoptheme/org.lydark.mystical.desktop
copy_tree "$SOURCE/wallpaper" \
  /usr/share/wallpapers/org.lydark.mystical.wallpaper

install -d "$(dest /usr/share/lyd/mystical)"
cp -a "$SOURCE/icons" "$(dest /usr/share/lyd/mystical/)"
install -m 0644 "$SOURCE/README.md" "$(dest /usr/share/lyd/mystical/README.md)"

# XDG defaults apply to new users while respecting settings already saved in
# an individual user's ~/.config directory.
install -d "$(dest /etc/xdg)"
cat > "$(dest /etc/xdg/kdeglobals)" <<'EOF'
[General]
ColorScheme=Mystical
AccentColor=152,116,196

[KDE]
widgetStyle=Breeze

[Icons]
Theme=Breeze
EOF
cat > "$(dest /etc/xdg/plasmarc)" <<'EOF'
[Theme]
name=org.lydark.mystical.desktop
EOF
cat > "$(dest /etc/xdg/ksplashrc)" <<'EOF'
[KSplash]
Theme=org.lydark.mystical.desktop
EOF
install -d "$(dest /etc/gtk-3.0)"
cat > "$(dest /etc/gtk-3.0/settings.ini)" <<'EOF'
[Settings]
gtk-theme-name=Breeze
gtk-application-prefer-dark-theme=1
EOF

# Preserve the source tree and installer for future edits/re-application.
if [[ "$SOURCE" != "$(dest /usr/share/lyd/themes/mystical)" ]]; then
  install -d "$(dest /usr/share/lyd/themes/mystical)"
  cp -a "$SOURCE/." "$(dest /usr/share/lyd/themes/mystical)/"
fi
install -d "$(dest /usr/local/lib/lyd)"
INSTALLER_SOURCE="$SCRIPT_DIR/$(basename -- "$0")"
INSTALLER_TARGET="$(dest /usr/local/lib/lyd/install-mystical-theme.sh)"
if [[ "$(realpath -m "$INSTALLER_SOURCE")" != "$(realpath -m "$INSTALLER_TARGET")" ]]; then
  install -m 0755 "$INSTALLER_SOURCE" "$INSTALLER_TARGET"
fi

echo "Mystical KDE theme installed under $ROOT."
