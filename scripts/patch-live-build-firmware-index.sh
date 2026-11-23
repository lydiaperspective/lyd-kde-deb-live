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

# Debian publishes Contents indexes inside each archive component, rather
# than at the suite root as expected by older live-build releases.
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

# Ubuntu's packaged live-build can leave LB_PARENT_ARCHIVE_AREAS empty in
# non-derivative Debian builds. The installer firmware scan then constructs
# the invalid URL .../dists/trixie//Contents-amd64.gz. Reuse the configured
# archive areas for the parent mirror in that case.
text = installer_path.read_text()
marker = "Set_defaults"
fallback = '''Set_defaults

# Debian is not a derivative: use the configured archive components for
# the parent-mirror firmware Contents lookup as well.
if [ "${LB_DERIVATIVE}" != "true" ] && [ -z "${LB_PARENT_ARCHIVE_AREAS:-}" ]
then
    LB_PARENT_ARCHIVE_AREAS="${LB_ARCHIVE_AREAS}"
fi'''
if 'LB_PARENT_ARCHIVE_AREAS="${LB_ARCHIVE_AREAS}"' not in text:
    if marker not in text:
        raise SystemExit("Could not find Set_defaults in Debian Installer helper")
    text = text.replace(marker, fallback, 1)
installer_path.write_text(text)

if 'LB_PARENT_ARCHIVE_AREAS="${LB_ARCHIVE_AREAS}"' not in installer_path.read_text():
    raise SystemExit("Debian Installer archive-area fallback was not applied")
print("Patched kernel Contents lookup and Debian Installer parent archive-area fallback.")
PY

grep -F '/${_ARCHIVE_AREA}/Contents-${LB_ARCHITECTURES}.gz' "$KERNEL_SCRIPT" >/dev/null
grep -F 'LB_PARENT_ARCHIVE_AREAS="${LB_ARCHIVE_AREAS}"' "$INSTALLER_SCRIPT" >/dev/null
