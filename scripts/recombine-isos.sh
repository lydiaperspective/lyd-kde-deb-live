#!/usr/bin/env bash
set -Eeuo pipefail

# Reconstruct each ISO from its numbered .part-* assets and verify its SHA256.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

shopt -s nullglob
parts_found=0

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
  parts_found=1
done

if [ "$parts_found" -eq 0 ]; then
  printf 'No ISO part sets found. Keep this script beside the downloaded .part-* and .sha256 files.\n' >&2
  exit 1
fi
