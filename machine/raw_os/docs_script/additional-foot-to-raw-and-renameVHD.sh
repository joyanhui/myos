#!/usr/bin/env bash
# Add a VHD footer to a raw disk image and rename it in place to .vhd.
# Output (same dir, .raw -> .vhd) is a fixed VHD whose data area is exactly the
# original raw content (GPT at offset 0 + file-end footer), usable by Hyper-V
# Gen1 (.vhd accepted).
# Requires qemu-img in PATH (nix shell nixpkgs#qemu).
# Usage: additional-foot-to-raw-and-renameVHD.sh <image.raw>
set -euo pipefail

raw=${1:?usage: additional-foot-to-raw-and-renameVHD.sh <image.raw>}
[ -f "$raw" ] || { echo "error: not a file: $raw" >&2; exit 1; }
case "$raw" in
  *.raw) out="${raw%.raw}.vhd" ;;
  *)     out="${raw}.vhd" ;;
esac
[ "$out" != "$raw" ] || { echo "error: output same as input" >&2; exit 1; }

command -v qemu-img >/dev/null 2>&1 || { echo "error: qemu-img not found (run: nix shell nixpkgs#qemu -c $0 '$raw')" >&2; exit 1; }

size=$(stat -c %s "$raw")
echo "raw:  $raw ($size bytes)"
echo "vhd:  $out"

qemu-img create -f vpc -o subformat=fixed,size="$size" "$out" >/dev/null
dd if="$raw" of="$out" bs=4M conv=notrunc status=progress 2>&1 | tail -1

echo "validate footer:"
off=$(( $(stat -c %s "$out") - 512 ))
dd if="$out" bs=1 skip="$off" count=8 2>/dev/null
echo

rm -f "$raw"
echo "done: $out (raw source removed)"