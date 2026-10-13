#!/usr/bin/env bash
# Enlarge a raw image and optionally resize its Btrfs root partition.
# Usage: resize-raw-image.sh <image.raw> <new-size> [--resize-btrfs|--skip-btrfs-resize]
set -euo pipefail

usage() {
  echo "usage: $0 <image.raw> <new-size> [--resize-btrfs|--skip-btrfs-resize]" >&2
  exit 2
}

[ "$#" -ge 2 ] || usage
image=$1
new_size=$2
resize_btrfs=0
case "${3:---skip-btrfs-resize}" in
  --resize-btrfs) resize_btrfs=1 ;;
  --skip-btrfs-resize) ;;
  *) usage ;;
esac

[ -f "$image" ] || { echo "error: image is not a regular file: $image" >&2; exit 1; }
command -v stat >/dev/null || { echo "error: stat is required" >&2; exit 1; }
command -v truncate >/dev/null || { echo "error: truncate is required" >&2; exit 1; }
command -v numfmt >/dev/null || { echo "error: numfmt is required" >&2; exit 1; }
command -v sgdisk >/dev/null || { echo "error: sgdisk is required" >&2; exit 1; }
command -v btrfs >/dev/null || { echo "error: btrfs-progs is required" >&2; exit 1; }

signature=$(dd if="$image" bs=1 skip=512 count=8 status=none 2>/dev/null || true)
[ "$signature" = 'EFI PART' ] || { echo "error: image does not contain a GPT header" >&2; exit 1; }
current_bytes=$(stat -c '%s' "$image")
case "$current_bytes" in
  ''|*[!0-9]*) echo "error: invalid current image size: $current_bytes" >&2; exit 1 ;;
esac
current_gib=$(awk -v bytes="$current_bytes" 'BEGIN { printf "%.2f", bytes / 1073741824 }')
echo "image: $image"
echo "current virtual size: ${current_gib} GiB"

new_bytes=$(numfmt --from=iec "$new_size" 2>/dev/null || true)
case "$new_bytes" in
  ''|*[!0-9]*) echo "error: invalid image size: $new_size" >&2; exit 1 ;;
esac
[ $((new_bytes % 512)) -eq 0 ] || { echo "error: image size must be a multiple of 512 bytes: $new_size" >&2; exit 1; }
if [ "$new_bytes" -le "$current_bytes" ]; then
  echo "error: refusing to shrink or keep the image at its current size: $current_bytes -> $new_bytes bytes" >&2
  exit 1
fi

start=$(LC_ALL=C sgdisk -i 2 "$image" | sed -n 's/^First sector: *\([0-9][0-9]*\).*/\1/p')
case "$start" in
  ''|*[!0-9]*) echo "error: partition 2 start sector could not be read" >&2; exit 1 ;;
esac

# Do not use a shrink operation: truncate is only reached after the size check above.
truncate -s "$new_bytes" "$image"
actual_bytes=$(stat -c '%s' "$image")
if [ "$actual_bytes" -lt "$current_bytes" ] || [ "$actual_bytes" -ne "$new_bytes" ]; then
  echo "error: image size verification failed: expected $new_bytes bytes, got $actual_bytes bytes" >&2
  exit 1
fi
sgdisk -e "$image" >/dev/null
sgdisk -d 2 -n "2:${start}:0" -t 2:8304 -c 2:nixos-root "$image" >/dev/null
last=$(LC_ALL=C sgdisk -i 2 "$image" | sed -n 's/^Last sector: *\([0-9][0-9]*\).*/\1/p')
expected_last=$((new_bytes / 512 - 34))
[ "$last" = "$expected_last" ] || { echo "error: partition 2 resize verification failed: expected end $expected_last, got $last" >&2; exit 1; }

echo "image and partition 2 expanded"
[ "$resize_btrfs" -eq 1 ] || { echo 'Btrfs resize skipped'; exit 0; }

command -v losetup >/dev/null || { echo "error: losetup is required" >&2; exit 1; }
loop=$(losetup --find --show --partscan "$image")
cleanup() {
  [ -n "${mountpoint:-}" ] && umount "$mountpoint" 2>/dev/null || true
  losetup -d "$loop" 2>/dev/null || true
  rmdir "${mountpoint:-}" 2>/dev/null || true
}
trap cleanup EXIT
udevadm settle 2>/dev/null || true
root_partition="${loop}p2"
[ -b "$root_partition" ] || { echo "error: root partition was not created: $root_partition" >&2; exit 1; }
mountpoint=$(mktemp -d)
mount "$root_partition" "$mountpoint"
btrfs filesystem resize max "$mountpoint"
echo 'Btrfs filesystem expanded'
