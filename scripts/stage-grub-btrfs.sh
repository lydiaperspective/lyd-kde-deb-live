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
# Debian 13 can return an empty parsed subvolume UUID on some Btrfs layouts.
# Fall back to the filesystem UUID rather than aborting snapshot menu generation.
python3 - "$WORK/grub-btrfs/41_snapshots-btrfs" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = 'root_uuid_subvolume=$(awk -F":" \'match($1, /(^[ \\t]+UUID)/) {sub(/^[ \\t]+/, "", $2); print $2}\' <<< "$root_uuid_subvolume")'
new = old + '\n[ -n "$root_uuid_subvolume" ] || root_uuid_subvolume="$root_uuid"'
if old not in s:
    raise SystemExit("Could not apply Debian 13 root UUID compatibility patch to grub-btrfs.")
p.write_text(s.replace(old, new, 1))
PY
make -C "$WORK/grub-btrfs" DESTDIR="$ROOT" PREFIX=/usr SYSTEMD=true GRUB_UPDATE_EXCLUDE=true install
