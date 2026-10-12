#!/usr/bin/env bash
# Create grubx64.efi that boots nixos.raw via loopback from a host NTFS partition.
# Reads kernel/initrd/init from a NixOS boot.json and embeds a static grub.cfg.
# Usage:
#   create-grubx64-efi.sh [boot.json] [-o output.efi] [-s] [--serial]
#   boot.json defaults to /run/current-system/boot.json (post-rebuild on the img).
#   -s / --serial: embed serial console init (debug on QEMU; omit for real hardware).
set -euo pipefail

bootjson=${1:-/run/current-system/boot.json}
out=grubx64.efi
serial=0
args=()
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out=$2; shift 2 ;;
    -s|--serial) serial=1; shift ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) bootjson=$1; shift ;;
  esac
done

[ -f "$bootjson" ] || { echo "error: boot.json not found: $bootjson" >&2; exit 1; }
command -v jq >/dev/null || { echo "error: jq required" >&2; exit 1; }

kernel=$(jq -r '."org.nixos.bootspec.v1".kernel' "$bootjson")
initrd=$(jq -r '."org.nixos.bootspec.v1".initrd' "$bootjson")
init=$(jq -r '."org.nixos.bootspec.v1".init' "$bootjson")
params=$(jq -r '."org.nixos.bootspec.v1".kernelParams | join(" ")' "$bootjson")

[ "$kernel" != "null" ] && [ -n "$kernel" ] || { echo "error: no kernel in boot.json" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/grub.cfg" <<EOF
insmod ntfs
insmod part_gpt
insmod btrfs
insmod search
insmod search_fs_file
insmod configfile
insmod normal
insmod linux
insmod loopback
insmod all_video
EOF
if [ "$serial" = 1 ]; then
  cat >> "$tmp/grub.cfg" <<EOF
serial --unit=0 --speed=115200
terminal_input serial
terminal_output serial
EOF
fi
cat >> "$tmp/grub.cfg" <<EOF
search --no-floppy --set=root --file /OS-img/nixos.raw
set vdisk=(\$root)/OS-img/nixos.raw
loopback loop0 \$vdisk
linux (loop0,gpt2)$kernel init=$init $params
initrd (loop0,gpt2)$initrd
boot
EOF

find_mksa() {
  if command -v grub-mkstandalone >/dev/null 2>&1; then
    MKSA=$(command -v grub-mkstandalone)
  elif [ -x /nix/store/*grub-*/bin/grub-mkstandalone ]; then
    MKSA=$(ls -1 /nix/store/*grub-*/bin/grub-mkstandalone | head -1)
  else
    echo "error: grub-mkstandalone not found" >&2
    echo "  on the img:  nix profile install nixpkgs#grub2_efi" >&2
    echo "  on host:     nix shell nixpkgs#grub2_efi -c ./create-grubx64-efi.sh" >&2
    exit 1
  fi
}
find_mksa

moddir="$(dirname "$(dirname "$MKSA")")/lib/grub/x86_64-efi"
[ -d "$moddir" ] || moddir=$(find /nix/store -maxdepth 1 -type d -name 'grub-*' | while read -r d; do
  [ -d "$d/lib/grub/x86_64-efi" ] && echo "$d/lib/grub/x86_64-efi" && break
done)
[ -d "$moddir" ] || { echo "error: grub x86_64-efi module dir not found" >&2; exit 1; }

"$MKSA" -O x86_64-efi -d "$moddir" --compress=no \
  --modules="ntfs part_gpt btrfs ext2 fat search search_fs_file configfile normal linux echo all_video loopback" \
  --output="$out" "boot/grub/grub.cfg=$tmp/grub.cfg"

echo "created: $out"
echo "deploy: copy to ESP/EFI diskpart"
