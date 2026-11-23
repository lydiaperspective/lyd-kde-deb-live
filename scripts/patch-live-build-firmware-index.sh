#!/bin/sh
set -eu

SCRIPT="/usr/lib/live/build/lb_chroot_linux-image"

if [ ! -f "$SCRIPT" ]; then
  echo "live-build kernel helper not found: $SCRIPT" >&2
  exit 1
fi

python3 - "$SCRIPT" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()

old_parent = 'wget ${WGET_OPTIONS} ${LB_PARENT_MIRROR_CHROOT}/dists/${LB_PARENT_DISTRIBUTION}/Contents-${LB_ARCHITECTURES}.gz -O - | gunzip -c > cache/contents.chroot/contents.${LB_PARENT_DISTRIBUTION}.${LB_ARCHITECTURES}'
new_parent = '''# Debian publishes Contents indexes inside each archive component.
        : > cache/contents.chroot/contents.${LB_PARENT_DISTRIBUTION}.${LB_ARCHITECTURES}
        for _ARCHIVE_AREA in ${LB_ARCHIVE_AREAS}
        do
          wget ${WGET_OPTIONS} ${LB_PARENT_MIRROR_CHROOT}/dists/${LB_PARENT_DISTRIBUTION}/${_ARCHIVE_AREA}/Contents-${LB_ARCHITECTURES}.gz -O - | gunzip -c >> cache/contents.chroot/contents.${LB_PARENT_DISTRIBUTION}.${LB_ARCHITECTURES}
        done'''

old_derivative = 'wget ${WGET_OPTIONS} ${LB_MIRROR_CHROOT}/dists/${LB_DISTRIBUTION}/Contents-${LB_ARCHITECTURES}.gz -O - | gunzip -c > cache/contents.chroot/contents.${LB_DISTRIBUTION}.${LB_ARCHITECTURES}'
new_derivative = '''# Debian publishes Contents indexes inside each archive component.
            : > cache/contents.chroot/contents.${LB_DISTRIBUTION}.${LB_ARCHITECTURES}
            for _ARCHIVE_AREA in ${LB_ARCHIVE_AREAS}
            do
              wget ${WGET_OPTIONS} ${LB_MIRROR_CHROOT}/dists/${LB_DISTRIBUTION}/${_ARCHIVE_AREA}/Contents-${LB_ARCHITECTURES}.gz -O - | gunzip -c >> cache/contents.chroot/contents.${LB_DISTRIBUTION}.${LB_ARCHITECTURES}
            done'''

changed = False
if old_parent in text:
    text = text.replace(old_parent, new_parent)
    changed = True
if old_derivative in text:
    text = text.replace(old_derivative, new_derivative)
    changed = True

if not changed:
    if "/${_ARCHIVE_AREA}/Contents-${LB_ARCHITECTURES}.gz" in text:
        print("live-build firmware index lookup is already component-aware")
        raise SystemExit(0)
    raise SystemExit("Could not find expected Contents index lookup in " + str(path))

path.write_text(text)
print("Patched live-build to read Contents indexes from each configured archive component.")
PY

grep -F '/${_ARCHIVE_AREA}/Contents-${LB_ARCHITECTURES}.gz' "$SCRIPT" >/dev/null
