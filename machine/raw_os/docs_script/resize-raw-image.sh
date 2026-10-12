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
command -v qemu-img >/dev/null || { echo "error: qemu-img is required" >&2; exit 1; }
command -v sgdisk >/dev/null || { echo "error: sgdisk is required" >&2; exit 1; }
command -v btrfs >/dev/null || { echo "error: btrfs-progs is required" >&2; exit 1; }

format=$(qemu-img info --output=json "$image" | jq -r '.format')
[ "$format" = "raw" ] || { echo "error: image format must be raw, got: $format" >&2; exit 1; }
current_bytes=$(qemu-img info --output=json "$image" | jq -r '."virtual-size"')
case "$current_bytes" in
  ''|*[!0-9]*) echo "error: invalid current image size: $current_bytes" >&2; exit 1 ;;
esac
current_gib=$(awk -v bytes="$current_bytes" 'BEGIN { printf "%.2f", bytes / 1073741824 }')
echo "image: $image"
echo "current virtual size: ${current_gib} GiB"

new_bytes=$(qemu-img measure --size "$new_size" 2>/dev/null | awk -F: '/required size:/ {gsub(/ /, "", $2); print $2}')
case "$new_bytes" in
  ''|*[!0-9]*) echo "error: invalid image size: $new_size" >&2; exit 1 ;;
esac
if [ "$new_bytes" -le "$current_bytes" ]; then
  echo "error: refusing to shrink or keep the image at its current size: $current_bytes -> $new_bytes bytes" >&2
  exit 1
fi

# Do not pass --shrink: qemu-img must only grow this raw image.
qemu-img resize "$image" "$new_size"
actual_bytes=$(qemu-img info --output=json "$image" | jq -r '."virtual-size"')
if [ "$actual_bytes" -lt "$current_bytes" ] || [ "$actual_bytes" -ne "$new_bytes" ]; then
  echo "error: image size verification failed: expected $new_bytes bytes, got $actual_bytes bytes" >&2
  exit 1
fi
sgdisk -e "$image" >/dev/null
start=$(sgdisk -i 2 "$image" | awk -F: '/First sector/ {gsub(/ /, "", $2); print $2}')
[ -n "$start" ] || { echo "error: partition 2 was not found; image size was changed but partition was not resized" >&2; exit 1; }
sgdisk -d 2 -n "2:${start}:0" -t 2:8304 -c 2:nixos-root "$image" >/dev/null

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
