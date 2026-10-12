#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VM_DIR="${MACOS_VM_DIR:-/home/nixos/vdisks/macos}"
REIMS_DIR="$VM_DIR/reims"
SRC="${REIMS_SRC:-/tmp/reims-vgpu}"
REPO_URL="https://github.com/steelbrain/reims-vgpu"

for tool in git nix curl; do
    command -v "$tool" >/dev/null || { echo "missing tool: $tool" >&2; exit 1; }
done

if [ ! -f "$SRC/vendor/qemu/configure" ]; then
    echo "== clone reims-vgpu (vendor/qemu submodule included)"
    rm -rf "$SRC"
    git clone --recursive --depth 1 "$REPO_URL" "$SRC"
fi

mkdir -p "$REIMS_DIR"

pc_dir() {
    local out
    out="$(nix build "nixpkgs#$1" --no-link --print-out-paths 2>/dev/null | tail -n 1)"
    local path
    if [ -d "$out/lib/pkgconfig" ]; then
        path="$out/lib/pkgconfig"
    elif [ -d "$out/share/pkgconfig" ]; then
        path="$out/share/pkgconfig"
    else
        path=""
    fi
    printf '%s' "$path"
}

PKG_CONFIG_PATH=""
for p in glib.dev pixman zlib.dev pcre2.dev libffi.dev libslirp; do
    d="$(pc_dir "$p")"
    [ -n "$d" ] && PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$d"
done
export PKG_CONFIG_PATH="${PKG_CONFIG_PATH#:}"

echo "== build reims qemu (x86_64-softmmu, backend vulkan)"
nix shell nixpkgs#meson nixpkgs#ninja nixpkgs#pkg-config nixpkgs#glib.dev nixpkgs#glib nixpkgs#pixman nixpkgs#zlib.dev nixpkgs#zlib nixpkgs#python3 nixpkgs#gcc13 nixpkgs#bison nixpkgs#flex nixpkgs#libslirp \
    --command bash -c "
unset PKG_CONFIG_PATH_x86_64_unknown_linux_gnu
export PKG_CONFIG_PATH='$PKG_CONFIG_PATH'
cd '$SRC'
bash scripts/qemu-build/qemu-build.sh --target x86_64 --backend vulkan
"

echo "== build reims-vgpu-efi GOP rom"
nix shell nixpkgs#rustup --command bash -c "
rustup default stable >/dev/null 2>&1 || true
rustup target add x86_64-unknown-uefi >/dev/null 2>&1 || true
cd '$SRC'
bash crates/reims-vgpu-efi/scripts/reims-vgpu-efi-rom/reims-vgpu-efi-rom.sh
"

echo "== stage artifacts into $REIMS_DIR"
cp -f "$SRC/vendor/qemu/build/qemu-system-x86_64" "$REIMS_DIR/"
cp -f "$SRC/crates/reims-vgpu-efi/out/reims-vgpu-gop.rom" "$REIMS_DIR/"
rm -rf "$REIMS_DIR/qemu-bundle"
cp -r "$SRC/vendor/qemu/build/qemu-bundle" "$REIMS_DIR/"

MESA="$(nix build nixpkgs#mesa --no-link --print-out-paths 2>/dev/null | tail -n 1)"
LOADER="$(nix build nixpkgs#vulkan-loader --no-link --print-out-paths 2>/dev/null | tail -n 1)"

cat > "$REIMS_DIR/reims.env" <<EOF
QEMU_BIN=$REIMS_DIR/qemu-system-x86_64
GOP_ROM=$REIMS_DIR/reims-vgpu-gop.rom
DZN_ICD=$MESA/share/vulkan/icd.d/dzn_icd.x86_64.json
LVP_ICD=$MESA/share/vulkan/icd.d/lvp_icd.x86_64.json
LIBVULKAN=$LOADER/lib
EOF

echo
echo "built ok:"
ls -la "$REIMS_DIR"
echo "env: $REIMS_DIR/reims.env"
echo "next: $SCRIPT_DIR/start.sh"
