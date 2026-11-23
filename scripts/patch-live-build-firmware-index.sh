#!/bin/sh
set -eu

KERNEL_SCRIPT="/usr/lib/live/build/lb_chroot_linux-image"

if [ ! -f "$KERNEL_SCRIPT" ]; then
  echo "live-build helper not found: $KERNEL_SCRIPT" >&2
  exit 1
fi

python3 - "$KERNEL_SCRIPT" <<'PY'
from pathlib import Path
import sys

kernel_path = Path(sys.argv[1])
text = kernel_path.read_text()

# Debian publishes Contents indexes inside each archive component, rather
# than at the suite root as expected by older live-build releases.
old_parent = 'wget ${WGET_OPTIONS} ${LB_PARENT_MIRROR_CHROOT}/dists/${LB_PARENT_DISTRIBUTION}/Contents-${LB_ARCHITECTURES}.gz -O - | gunzip -c > cache/contents.chroot/contents.${LB_PARENT_DISTRIBUTION}.${LB_ARCHITECTURES}'
new_parent = '''# Debian publishes Contents indexes inside each archive component.
        : > cache/contents.chroot/contents.${LB_PARENT_DISTRIBUTION}.${LB_ARCHITECTURES}
        for _ARCHIVE_AREA in ${LB_PARENT_ARCHIVE_AREAS:-${LB_ARCHIVE_AREAS}}
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

if old_parent in text:
    text = text.replace(old_parent, new_parent)
if old_derivative in text:
    text = text.replace(old_derivative, new_derivative)
if "/${_ARCHIVE_AREA}/Contents-${LB_ARCHITECTURES}.gz" not in text:
    raise SystemExit("Could not patch the kernel helper's Contents lookup")
kernel_path.write_text(text)
print("Patched the kernel firmware Contents lookup.")
PY

grep -F '/${_ARCHIVE_AREA}/Contents-${LB_ARCHITECTURES}.gz' "$KERNEL_SCRIPT" >/dev/null
