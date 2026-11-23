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

# The Debian Installer firmware scan uses parent archive areas. Ubuntu's
# live-build defaults can leave that list empty for a non-derivative Debian
# build, producing a suite-root Contents URL that does not exist on Debian.
# Fall back at the point of use so later configuration/default processing
# cannot overwrite the value before the scan runs.
text = installer_path.read_text()
old_areas = "for _PARENT_ARCHIVE_AREA in ${LB_PARENT_ARCHIVE_AREAS}"
new_areas = "for _PARENT_ARCHIVE_AREA in ${LB_PARENT_ARCHIVE_AREAS:-${LB_ARCHIVE_AREAS}}"
old_nonfree = "echo ${LB_PARENT_ARCHIVE_AREAS} | grep -qs"
new_nonfree = "echo ${LB_PARENT_ARCHIVE_AREAS:-${LB_ARCHIVE_AREAS}} | grep -qs"
if old_areas not in text:
    raise SystemExit("Could not find Debian Installer parent-area Contents loop")
if old_nonfree not in text:
    raise SystemExit("Could not find Debian Installer non-free firmware check")
text = text.replace(old_areas, new_areas, 1)
text = text.replace(old_nonfree, new_nonfree, 1)
installer_path.write_text(text)

patched = installer_path.read_text()
if new_areas not in patched or new_nonfree not in patched:
    raise SystemExit("Debian Installer archive-area fallback was not applied")
print("Patched kernel and Debian Installer Contents lookups to use component archive areas.")
PY

grep -F '/${_ARCHIVE_AREA}/Contents-${LB_ARCHITECTURES}.gz' "$KERNEL_SCRIPT" >/dev/null
grep -F 'LB_PARENT_ARCHIVE_AREAS="${LB_ARCHIVE_AREAS}"' "$INSTALLER_SCRIPT" >/dev/null
