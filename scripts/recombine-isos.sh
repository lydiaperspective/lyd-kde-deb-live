#!/usr/bin/env bash
set -Eeuo pipefail

# Reconstruct each ISO from its numbered .part-* assets and verify its SHA256.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

shopt -s nullglob
parts_found=0
cleanup_parts=()
cleanup_checksums=()

for first_part in ./*.iso.part-000; do
  [ -f "$first_part" ] || continue
  iso="${first_part%.part-000}"
  checksum="$iso.sha256"
  parts=( "$iso".part-* )

  if [ ! -f "$checksum" ]; then
    printf 'Missing checksum file: %s\n' "$checksum" >&2
    exit 1
  fi

  printf 'Recombining %s from %d parts...\n' "$iso" "${#parts[@]}"
  tmp="$iso.recombined.tmp"
  rm -f -- "$tmp"
  cat -- "${parts[@]}" > "$tmp"
  mv -- "$tmp" "$iso"

  if ! sha256sum --check "$checksum"; then
    rm -f -- "$iso"
    printf 'Checksum verification failed for %s; reconstructed file removed.\n' "$iso" >&2
    exit 1
  fi

  printf 'Verified: %s\n' "$iso"
  cleanup_parts+=( "${parts[@]}" )
  cleanup_checksums+=( "$checksum" )
  parts_found=1
done

if [ "$parts_found" -eq 0 ]; then
  printf 'No ISO part sets found. Keep this script beside the downloaded .part-* and .sha256 files.\n' >&2
  exit 1
fi

printf '\nAll reconstructed ISO files passed SHA256 verification.\n'
read -r -p "Delete the downloaded .part-* files and matching .iso.sha256 files? [y/N] " reply
case "$reply" in
  [yY]|[yY][eE][sS])
    rm -f -- "${cleanup_parts[@]}" "${cleanup_checksums[@]}"
    printf 'Deleted the downloaded parts and checksum files. Reconstructed ISO files were kept.\n'
    ;;
  *)
    printf 'Keeping the downloaded parts and checksum files.\n'
    ;;
esac
