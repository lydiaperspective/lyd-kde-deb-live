#!/usr/bin/env bash
set -Eeuo pipefail
PROFILE="\${1:-}"
ROOT_DIR="$(cd -- "$(dirname -- "\${BASH_SOURCE[0]}")/.." && pwd)"
[[ "$PROFILE" == desktop || "$PROFILE" == server ]] || {
  echo "Usage: sudo bash scripts/install-existing-debian.sh {desktop|server}" >&2; exit 2;
}
[[ $EUID -eq 0 ]] || { echo "Run with sudo." >&2; exit 1; }
. /etc/os-release
[[ "\${ID:-}" == debian && "\${VERSION_ID:-}" == 13 ]] || {
  echo "Debian 13 (Trixie) is required; found \${PRETTY_NAME:-unknown}." >&2; exit 1;
}
[[ "$(dpkg --print-architecture)" == amd64 ]] || { echo "This build targets amd64." >&2; exit 1; }
[[ -d "$ROOT_DIR/themes/mystical" && -f "$ROOT_DIR/profiles/$PROFILE/config/package-lists/$PROFILE.list.chroot" ]] || {
  echo "Run this script from a clone of https://github.com/lydiaperspective/lyd-kde-deb-live" >&2; exit 1;
}
install -d -m 0755 /var/log/lyd-install
LOG="/var/log/lyd-install/lyd-install-$PROFILE-$(date +%Y%m%d-%H%M%S).log"
BACKUP="/var/backups/lyd-install/$(date +%Y%m%d-%H%M%S)"
install -d -m 0700 "$BACKUP"
exec > >(tee -a "$LOG") 2>&1
log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
ask() {
  local answer
  printf '\n%s [y/N] ' "$1" >/dev/tty
  IFS= read -r answer </dev/tty || return 1
  [[ "$answer" =~ ^([yY]|[yY][eE][sS])$ ]]
}
backup_file() {
  [[ -e "$1" ]] || return 0
  install -d "$BACKUP$(dirname "$1")"
  cp -a "$1" "$BACKUP$1"
}
log "Installing lyd profile: $PROFILE"
log "Log: $LOG"
log "Backups: $BACKUP"

# Enable the Debian archive areas used by the ISO. Only official Trixie sources
# are edited; modified source files receive timestamped backups.
python3 <<'PY'
from pathlib import Path
import re, shutil
from datetime import datetime
wanted = {"contrib", "non-free", "non-free-firmware"}
stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
paths = [Path("/etc/apt/sources.list"), *Path("/etc/apt/sources.list.d").glob("*.list"),
         *Path("/etc/apt/sources.list.d").glob("*.sources")]
official = re.compile(r"https?://(?:deb|security)\.debian\.org(?:/|$)")
for p in paths:
    if not p.is_file(): continue
    old = p.read_text(); new = old
    if p.suffix == ".sources":
        chunks = re.split(r"(\n\s*\n)", new)
        for i, c in enumerate(chunks):
            u = re.search(r"(?mi)^URIs:\s*(.+)$", c)
            s = re.search(r"(?mi)^Suites:\s*(.+)$", c)
            if not u or not s or not official.search(u.group(1)) or not re.search(r"\btrixie(?:-updates|-security)?\b", s.group(1)): continue
            m = re.search(r"(?mi)^Components:\s*(.*)$", c)
            if m:
                missing = sorted(wanted - set(m.group(1).split()))
                if missing: c = c[:m.start(1)] + m.group(1) + " " + " ".join(missing) + c[m.end(1):]
            else: c = c.rstrip() + "\nComponents: main contrib non-free non-free-firmware\n"
            chunks[i] = c
        new = "".join(chunks)
    else:
        lines = []
        for line in new.splitlines():
            parts = line.split()
            if parts and parts[0] == "deb" and official.search(line):
                try:
                    ui = next(i for i,x in enumerate(parts) if x.startswith(("http://","https://")))
                    si = ui + 1
                    if si+1 < len(parts) and re.search(r"\btrixie(?:-updates|-security)?\b",parts[si]):
                        missing = sorted(wanted-set(parts[si+1:]))
                        if missing: line += " " + " ".join(missing)
                except StopIteration: pass
            lines.append(line)
        new = "\n".join(lines) + ("\n" if old.endswith("\n") else "")
    if new != old:
        shutil.copy2(p, p.with_name(p.name+".lyd-backup-"+stamp))
        p.write_text(new)
        print("Enabled Debian archive components in", p)
PY

mapfile -t PACKAGES < <(sed 's/#.*//' "$ROOT_DIR/profiles/$PROFILE/config/package-lists/$PROFILE.list.chroot" | xargs -n1 2>/dev/null | grep -E '^[a-zA-Z0-9][a-zA-Z0-9+.-]*$' || true)
PACKAGES+=(grub-common grub2-common librsvg2-bin fonts-dejavu-core)
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y "\${PACKAGES[@]}"

S="$ROOT_DIR/scripts"
install -D -m 0755 "$S/lydsys" /usr/local/sbin/lydsys
install -D -m 0755 "$S/lydsetup" /usr/local/bin/lydsetup
install -D -m 0755 "$S/lydhelp" /usr/local/bin/lydhelp
install -D -m 0755 "$S/lyd-btrfs-postinstall" /usr/local/sbin/lyd-btrfs-postinstall
install -D -m 0755 "$S/install-grub-theme.sh" /usr/local/lib/lyd/install-grub-theme.sh
install -D -m 0755 "$S/stage-grub-btrfs.sh" /usr/local/lib/lyd/stage-grub-btrfs.sh
if [[ "$PROFILE" == server ]]; then
  install -D -m 0755 "$S/lyd-firewall-postinstall" /usr/local/sbin/lyd-firewall-postinstall
fi

log "Installing pinned grub-btrfs v4.14 integration."
bash "$S/stage-grub-btrfs.sh" /
systemctl daemon-reload
if [[ "$(findmnt -n -o FSTYPE / 2>/dev/null || true)" == btrfs ]]; then
  systemctl enable --now grub-btrfsd.service
else
  log "Root is not Btrfs; grub-btrfsd will remain disabled."
fi

if [[ "$PROFILE" == desktop ]]; then
  for f in /etc/xdg/kdeglobals /etc/xdg/plasmarc /etc/xdg/ksplashrc /etc/gtk-3.0/settings.ini /etc/xdg/konsolerc; do backup_file "$f"; done
  bash "$S/install-mystical-theme.sh" --source "$ROOT_DIR/themes/mystical"
  INC="$ROOT_DIR/profiles/desktop/config/includes.chroot"
  install -D -m 0644 "$INC/usr/share/konsole/Lyd-Mystical.colorscheme" /usr/share/konsole/Lyd-Mystical.colorscheme
  install -D -m 0644 "$INC/usr/share/konsole/Lyd-Mystical.profile" /usr/share/konsole/Lyd-Mystical.profile
  install -D -m 0644 "$INC/etc/xdg/konsolerc" /etc/xdg/konsolerc
  log "Installed Mystical KDE theme and Konsole profile."
else
  systemctl enable --now ssh.service cockpit.socket tuned.service
  if ask "Apply lyd Firewalld policy (public zone; allow SSH/22 and Cockpit/9090)? Existing Firewalld config will be backed up."; then
    if [[ -d /etc/firewalld ]]; then install -d "$BACKUP/etc"; cp -a /etc/firewalld "$BACKUP/etc/firewalld"; fi
    /usr/local/sbin/lyd-firewall-postinstall
    systemctl enable --now firewalld.service
    firewall-cmd --reload
  else
    log "Kept existing Firewalld policy."
    systemctl enable --now firewalld.service
  fi
fi

if command -v update-grub >/dev/null 2>&1 && [[ -f /etc/default/grub ]]; then
  if ask "Apply Mystical GRUB theme? /etc/default/grub will be backed up and GRUB regenerated."; then
    bash "$S/install-grub-theme.sh" --source "$ROOT_DIR/themes/mystical/wallpaper/contents/images/1920x1080.svg"
  else log "Skipped GRUB theme."; fi
else log "GRUB not detected; skipped GRUB theme."; fi

if [[ "$(findmnt -n -o FSTYPE / 2>/dev/null || true)" == btrfs ]]; then
  if ask "Run lyd Btrfs/Snapper setup? It may create @home/@var subvolumes and edit /etc/fstab; inspect your existing layout first."; then
    backup_file /etc/fstab
    /usr/local/sbin/lyd-btrfs-postinstall
  else log "Skipped Btrfs/Snapper migration."; fi
else log "Root is not Btrfs; skipped Btrfs/Snapper setup."; fi

if [[ "$PROFILE" == desktop ]] && dpkg-query -W kwin-common >/dev/null 2>&1; then
  log "Aurorae is supplied by Debian's kwin-common plugin; no duplicate plugin installed."
fi
log "Completed profile $PROFILE. Review $LOG and backups in $BACKUP; reboot recommended."
