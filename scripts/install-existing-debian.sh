#!/usr/bin/env bash
# Install a lyd desktop or server profile onto an existing Debian 13 system.
set -Eeuo pipefail
PROFILE="${1:-}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
case "$PROFILE" in desktop|server) ;; *) echo "Usage: sudo bash scripts/install-existing-debian.sh {desktop|server}" >&2; exit 2 ;; esac
[[ $EUID -eq 0 ]] || { echo "Run with sudo." >&2; exit 1; }
. /etc/os-release
[[ "${ID:-}" == debian && "${VERSION_ID:-}" == 13 ]] || { echo "Debian 13 (Trixie) is required; found ${PRETTY_NAME:-unknown}." >&2; exit 1; }
[[ "$(dpkg --print-architecture)" == amd64 ]] || { echo "This build targets amd64." >&2; exit 1; }
[[ -d "$ROOT_DIR/themes/mystical" && -f "$ROOT_DIR/profiles/$PROFILE/config/package-lists/$PROFILE.list.chroot" ]] || { echo "Run from a clone of https://github.com/lydiaperspective/lyd-kde-deb-live" >&2; exit 1; }
[[ -t 0 && -t 1 ]] || { echo "Run from an interactive terminal; this script asks before system-level changes." >&2; exit 1; }

install -d -m 0755 /var/log/lyd-install
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="/var/log/lyd-install/lyd-install-$PROFILE-$STAMP.log"
BACKUP="/var/backups/lyd-install/$STAMP"
install -d -m 0700 "$BACKUP"
exec > >(tee -a "$LOG") 2>&1
log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
ask() { local answer; read -r -p "$1 [y/N] " answer || return 1; [[ "$answer" =~ ^([yY]|[yY][eE][sS])$ ]]; }
backup_file() { local source="$1"; [[ -e "$source" ]] || return 0; install -d "$BACKUP$(dirname "$source")"; cp -a -- "$source" "$BACKUP$source"; }
fail() { log "ERROR: $*"; exit 1; }

log "Installing lyd $PROFILE profile on Debian 13 amd64."
log "Log: $LOG"
log "Backups: $BACKUP"
log "No disk partitioning, Debian reinstall, bootloader replacement, or full-upgrade will be performed."

# Enable extra archive areas only in official Debian Trixie source entries.
python3 - "$BACKUP" <<'PY'
from pathlib import Path
import re, shutil, sys
backup = Path(sys.argv[1])
wanted = {"contrib", "non-free", "non-free-firmware"}
official = re.compile(r"https?://(?:deb|security)\.debian\.org(?:/|$)")
paths = [Path("/etc/apt/sources.list"), *Path("/etc/apt/sources.list.d").glob("*.list"), *Path("/etc/apt/sources.list.d").glob("*.sources")]
for path in paths:
    if not path.is_file(): continue
    original = path.read_text()
    updated = original
    if path.suffix == ".sources":
        chunks = re.split(r"(\n\s*\n)", updated)
        for i, chunk in enumerate(chunks):
            uris = re.search(r"(?mi)^URIs:\s*(.+)$", chunk)
            suites = re.search(r"(?mi)^Suites:\s*(.+)$", chunk)
            if not uris or not suites or not official.search(uris.group(1)) or not re.search(r"\btrixie(?:-updates|-security)?\b", suites.group(1)): continue
            components = re.search(r"(?mi)^Components:\s*(.*)$", chunk)
            if components:
                current = components.group(1).split()
                missing = [x for x in sorted(wanted) if x not in current]
                if missing: chunk = chunk[:components.start(1)] + components.group(1) + " " + " ".join(missing) + chunk[components.end(1):]
            else: chunk = chunk.rstrip() + "\nComponents: main contrib non-free non-free-firmware\n"
            chunks[i] = chunk
        updated = "".join(chunks)
    else:
        lines = []
        for line in updated.splitlines():
            parts = line.split()
            if parts and parts[0] == "deb" and official.search(line):
                try:
                    ui = next(i for i, x in enumerate(parts) if x.startswith(("http://", "https://")))
                    si = ui + 1
                    if si + 1 < len(parts) and re.search(r"\btrixie(?:-updates|-security)?\b", parts[si]):
                        missing = [x for x in sorted(wanted) if x not in parts[si + 1:]]
                        if missing: line += " " + " ".join(missing)
                except StopIteration: pass
            lines.append(line)
        updated = "\n".join(lines) + ("\n" if original.endswith("\n") else "")
    if updated != original:
        target = backup / path.relative_to("/")
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
        path.write_text(updated)
        print(f"Enabled Debian archive components in {path}; backup: {target}")
PY

mapfile -t PACKAGES < <(awk '{ sub(/#.*/, ""); gsub(/^[[:space:]]+|[[:space:]]+$/, ""); if ($0 != "") print $0 }' "$ROOT_DIR/profiles/$PROFILE/config/package-lists/$PROFILE.list.chroot")
EXTRA_PACKAGES=(git make inotify-tools python3 python3-btrfsutil rsync btrfs-progs snapper grub-common grub2-common librsvg2-bin fonts-dejavu-core)
log "Refreshing APT metadata and installing the selected ISO profile packages."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y "${PACKAGES[@]}" "${EXTRA_PACKAGES[@]}"

SCRIPTS="$ROOT_DIR/scripts"
install -D -m 0755 "$SCRIPTS/lydsys" /usr/local/sbin/lydsys
install -D -m 0755 "$SCRIPTS/lydsetup" /usr/local/bin/lydsetup
install -D -m 0755 "$SCRIPTS/lydhelp" /usr/local/bin/lydhelp
install -D -m 0755 "$SCRIPTS/lyd-btrfs-postinstall" /usr/local/sbin/lyd-btrfs-postinstall
install -D -m 0755 "$SCRIPTS/install-grub-theme.sh" /usr/local/lib/lyd/install-grub-theme.sh
install -D -m 0755 "$SCRIPTS/stage-grub-btrfs.sh" /usr/local/lib/lyd/stage-grub-btrfs.sh
install -D -m 0755 "$SCRIPTS/install-mystical-theme.sh" /usr/local/lib/lyd/install-mystical-theme.sh
install -D -m 0755 "$SCRIPTS/lyd-mystical-first-login" /usr/local/lib/lyd/lyd-mystical-first-login
if [[ "$PROFILE" == server ]]; then install -D -m 0755 "$SCRIPTS/lyd-firewall-postinstall" /usr/local/sbin/lyd-firewall-postinstall; fi

for helper in "$SCRIPTS/lydsys" "$SCRIPTS/lydsetup" "$SCRIPTS/lydhelp" "$SCRIPTS/lyd-btrfs-postinstall" "$SCRIPTS/install-grub-theme.sh" "$SCRIPTS/stage-grub-btrfs.sh"; do
  bash -n "$helper" || fail "Shell syntax check failed: $helper"
done

log "Installing pinned grub-btrfs v4.14 integration."
bash "$SCRIPTS/stage-grub-btrfs.sh" /
systemctl daemon-reload

if [[ "$PROFILE" == desktop ]]; then
  for file in /etc/xdg/kdeglobals /etc/xdg/plasmarc /etc/xdg/ksplashrc /etc/gtk-3.0/settings.ini /etc/xdg/konsolerc; do backup_file "$file"; done
  bash "$SCRIPTS/install-mystical-theme.sh" --source "$ROOT_DIR/themes/mystical"
  INC="$ROOT_DIR/profiles/desktop/config/includes.chroot"
  install -D -m 0644 "$INC/usr/share/konsole/Lyd-Mystical.colorscheme" /usr/share/konsole/Lyd-Mystical.colorscheme
  install -D -m 0644 "$INC/usr/share/konsole/Lyd-Mystical.profile" /usr/share/konsole/Lyd-Mystical.profile
  install -D -m 0644 "$INC/etc/xdg/konsolerc" /etc/xdg/konsolerc
  log "Installed Mystical KDE theme, wallpaper helper, and Konsole profile."
  if ask "Run the optional desktop cleanup now? This can remove LibreOffice and other optional extras from older/full KDE installations."; then
    /usr/local/sbin/lydsys run 20
  else
    log "Skipped optional desktop cleanup. You can run it later with: sudo lydsys run 20"
  fi
  DESKTOP_USER="${SUDO_USER:-}"
  if [[ -n "$DESKTOP_USER" && "$DESKTOP_USER" != root ]] && id "$DESKTOP_USER" >/dev/null 2>&1 && command -v lookandfeeltool >/dev/null 2>&1; then
    if ask "Apply the Mystical Global Theme to '$DESKTOP_USER' now?"; then
      USER_HOME="$(getent passwd "$DESKTOP_USER" | cut -d: -f6)"
      if [[ -n "$USER_HOME" && -d "$USER_HOME" ]]; then
        runuser -u "$DESKTOP_USER" -- env HOME="$USER_HOME" lookandfeeltool -a org.lydark.mystical.desktop ||
          log "Could not apply from this shell; select it in System Settings > Appearance > Global Theme."
      fi
    fi
  else
    log "Existing user's KDE settings were not overwritten; apply Mystical from System Settings > Appearance > Global Theme."
  fi
  if dpkg-query -W -f='${Status}' kwin-common 2>/dev/null | grep -q 'install ok installed'; then
    log "Aurorae runtime is provided by Debian kwin-common; no duplicate plugin installed."
  fi
else
  log "Server profile selected; no Plasma theme packages installed."
  systemctl enable ssh.service cockpit.socket tuned.service
  if command -v firewall-cmd >/dev/null 2>&1 && ask "Apply lyd Firewalld public-zone policy (SSH/22 and Cockpit/9090)? Existing rules will be backed up."; then
    if [[ -d /etc/firewalld ]]; then install -d "$BACKUP/etc"; cp -a /etc/firewalld "$BACKUP/etc/firewalld"; fi
    /usr/local/sbin/lyd-firewall-postinstall
    systemctl enable --now firewalld.service
    firewall-cmd --reload
  else
    log "Kept the existing Firewalld policy."
  fi
fi

if command -v update-grub >/dev/null 2>&1 && [[ -f /etc/default/grub ]]; then
  if ask "Apply Mystical GRUB theme? /etc/default/grub will be backed up and GRUB regenerated."; then
    backup_file /etc/default/grub
    bash "$SCRIPTS/install-grub-theme.sh" --source "$ROOT_DIR/themes/mystical/wallpaper/contents/images/1920x1080.svg"
  else log "Skipped Mystical GRUB theme."; fi
else log "GRUB not detected; skipped GRUB theme."; fi

ROOT_FS="$(findmnt -n -o FSTYPE / 2>/dev/null || true)"
if [[ "$ROOT_FS" == btrfs ]]; then
  if ask "Configure lyd Btrfs layout and Snapper/GRUB snapshots? This may create @home/@var and edit /etc/fstab; review layout first."; then
    backup_file /etc/fstab
    /usr/local/sbin/lyd-btrfs-postinstall
  else log "Skipped Btrfs/Snapper migration. Run sudo /usr/local/sbin/lyd-btrfs-postinstall after reviewing the layout."; fi
else
  log "Root filesystem is $ROOT_FS, not Btrfs. No conversion is attempted; snapshot setup skipped."
fi

log "Completed profile $PROFILE. Review $LOG and backups under $BACKUP."
log "A reboot is recommended after reviewing the results."
