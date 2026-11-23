#!/bin/sh
set -eu

KERNEL_SCRIPT="/usr/lib/live/build/lb_chroot_linux-image"
INSTALLER_SCRIPT="/usr/lib/live/build/lb_binary_debian-installer"

for SCRIPT in "$KERNEL_SCRIPT" "$INSTALLER_SCRIPT"; do
  if [ ! -f "$SCRIPT" ]; then
    echo "live-build helper not found: $SCRIPT" >&2
    exit 1
  fi
done

python3 - "$KERNEL_SCRIPT" "$INSTALLER_SCRIPT" <<'PY'
from pathlib import Path
import sys

kernel_path = Path(sys.argv[1])
installer_path = Path(sys.argv[2])

# The chroot kernel helper in Ubuntu's live-build package expects the old
# suite-root Contents index. Debian now publishes one index per component.
text = kernel_path.read_text()
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

if old_parent in text:
    text = text.replace(old_parent, new_parent)
if old_derivative in text:
    text = text.replace(old_derivative, new_derivative)
if "/${_ARCHIVE_AREA}/Contents-${LB_ARCHITECTURES}.gz" not in text:
    raise SystemExit("Could not patch the kernel helper's Contents lookup")
kernel_path.write_text(text)

# The Debian Installer helper has a separate firmware lookup. The Ubuntu
# live-build package omits the component directory from the URL it constructs.
text = installer_path.read_text()
old_parent_url = '/dists/${LB_PARENT_DISTRIBUTION}/Contents-${LB_ARCHITECTURES}.gz'
new_parent_url = '/dists/${LB_PARENT_DISTRIBUTION}/${_PARENT_ARCHIVE_AREA}/Contents-${LB_ARCHITECTURES}.gz'
old_derivative_url = '/dists/${LB_DISTRIBUTION}/Contents-${LB_ARCHITECTURES}.gz'
new_derivative_url = '/dists/${LB_DISTRIBUTION}/${_ARCHIVE_AREA}/Contents-${LB_ARCHITECTURES}.gz'

changed = False
if old_parent_url in text:
    text = text.replace(old_parent_url, new_parent_url)
    changed = True
if old_derivative_url in text:
    text = text.replace(old_derivative_url, new_derivative_url)
    changed = True

if not changed and (
    new_parent_url not in text and new_derivative_url not in text
):
    raise SystemExit("Could not find the Debian Installer firmware Contents lookup")

if old_parent_url in text or old_derivative_url in text:
    raise SystemExit("Debian Installer Contents lookup still contains a suite-root URL")

installer_path.write_text(text)
print("Patched both live-build kernel and Debian Installer firmware index lookups.")
PY

grep -F '/${_ARCHIVE_AREA}/Contents-${LB_ARCHITECTURES}.gz' "$KERNEL_SCRIPT" >/dev/null
grep -F '/${_PARENT_ARCHIVE_AREA}/Contents-${LB_ARCHITECTURES}.gz' "$INSTALLER_SCRIPT" >/dev/null
