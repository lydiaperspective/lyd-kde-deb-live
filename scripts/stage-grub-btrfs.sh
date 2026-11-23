#!/usr/bin/env bash
# Stage the upstream grub-btrfs integration into a live-build chroot tree.
set -Eeuo pipefail
ROOT="${1:?Usage: stage-grub-btrfs.sh TARGET_ROOT}"
ROOT="$(realpath -m "$ROOT")"
command -v git >/dev/null || { echo "git is required to stage grub-btrfs." >&2; exit 1; }
command -v make >/dev/null || { echo "make is required to stage grub-btrfs." >&2; exit 1; }
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
git clone --depth 1 --branch v4.14 https://github.com/Antynea/grub-btrfs.git "$WORK/grub-btrfs"
# Parse Btrfs subvolume UUID fields robustly; upstream v4.14 expected leading
# whitespace before UUID, while Debian's btrfs-progs prints the label at column 1.
python3 - "$WORK/grub-btrfs/41_snapshots-btrfs" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old_root = 'root_uuid_subvolume=$(awk -F":" \'match($1, /(^[ \\t]+UUID)/) {sub(/^[ \\t]+/, "", $2); print $2}\' <<< "$root_uuid_subvolume")'
new_root = 'root_uuid_subvolume=$(awk -F":" \'/^[[:space:]]*UUID[[:space:]]*:/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}\' <<< "$root_uuid_subvolume")'
old_boot = 'boot_uuid_subvolume=$(awk -F":" \'match($1, /(^[ \\t]+UUID)/) {sub(/^[ \\t]+/, "", $2); print $2}\' <<< "$boot_uuid_subvolume")'
new_boot = 'boot_uuid_subvolume=$(awk -F":" \'/^[[:space:]]*UUID[[:space:]]*:/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit}\' <<< "$boot_uuid_subvolume")'
if old_root not in s or old_boot not in s:
    raise SystemExit("Could not apply Debian Btrfs UUID parsing compatibility patch.")
s = s.replace(old_root, new_root, 1).replace(old_boot, new_boot, 1)
p.write_text(s)
PY
make -C "$WORK/grub-btrfs" DESTDIR="$ROOT" PREFIX=/usr SYSTEMD=true GRUB_UPDATE_EXCLUDE=true install
