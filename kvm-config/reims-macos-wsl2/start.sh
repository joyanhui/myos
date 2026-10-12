#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VM_DIR="${MACOS_VM_DIR:-/home/nixos/vdisks/macos}"
REIMS_DIR="$VM_DIR/reims"
RAM="${MACOS_RAM:-8G}"
CPUS="${MACOS_CPUS:-4}"
MAC_ADDR="${MACOS_MAC:-52:54:00:c9:18:27}"
SSH_PORT="${MACOS_SSH_PORT:-2222}"
VNC_DISPLAY="${MACOS_VNC_DISPLAY:-0}"
ICD_MODE="${REIMS_ICD:-auto}"
OSK="ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc"

for arg in "$@"; do
    case "$arg" in
        --sw) ICD_MODE="lvp" ;;
        --hw) ICD_MODE="dzn" ;;
        *) echo "usage: $0 [--sw|--hw]" >&2; exit 1 ;;
    esac
done

for file in OpenCore.qcow2 OVMF_CODE_4M.fd OVMF_VARS.fd macOS.qcow2; do
    [ -f "$VM_DIR/$file" ] || { echo "missing $VM_DIR/$file, run create.sh first" >&2; exit 1; }
done

[ -f "$REIMS_DIR/reims.env" ] || { echo "missing $REIMS_DIR/reims.env, run build.sh first" >&2; exit 1; }
. "$REIMS_DIR/reims.env"
[ -x "$QEMU_BIN" ] || { echo "missing reims qemu: $QEMU_BIN" >&2; exit 1; }

probe_icd() {
    VK_ICD_FILENAMES="$1" LD_LIBRARY_PATH="$LIBVULKAN" python3 - "$2" <<'PY'
import ctypes
import os
import sys

lib = os.path.join(sys.argv[1] if len(sys.argv) > 1 else "", "libvulkan.so.1")
try:
    vk = ctypes.CDLL(lib)
except Exception:
    sys.exit(1)

VK_SUCCESS = 0
count = ctypes.c_uint32(0)
result = vk.vkEnumeratePhysicalDevices(None, ctypes.byref(count), None)
if result != VK_SUCCESS or count.value == 0:
    sys.exit(1)
sys.exit(0)
PY
}

case "$ICD_MODE" in
    dzn)
        VK_ICD_FILENAMES="$DZN_ICD"
        ;;
    lvp)
        VK_ICD_FILENAMES="$LVP_ICD"
        ;;
    auto)
        if [ -n "${VK_ICD_FILENAMES:-}" ]; then
            :
        elif probe_icd "$DZN_ICD" "$LIBVULKAN"; then
            VK_ICD_FILENAMES="$DZN_ICD"
            echo "icd: dzn (hardware)"
        else
            VK_ICD_FILENAMES="$LVP_ICD"
            echo "icd: lvp (software, dzn has no device)"
        fi
        ;;
esac
export DISPLAY=:0
export GDK_BACKEND=x11
export XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir
unset WAYLAND_DISPLAY
export SDL_VIDEODRIVER=x11
export SDL_RENDER_DRIVER=software
export REIMS_VULKAN_DEVICE_INDEX=0
export VK_LOADER_LAYERS_DISABLE=all
export VK_ICD_FILENAMES
export REIMS_VGPU_GUEST_IMPORT=on
export REIMS_VGPU_DMABUF=off
export LD_LIBRARY_PATH="${LIBVULKAN:-}${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

if [ "$(cat /sys/module/kvm/parameters/ignore_msrs 2>/dev/null || echo N)" != "Y" ]; then
    echo 1 | sudo tee /sys/module/kvm/parameters/ignore_msrs >/dev/null
fi
sudo chmod 666 /dev/kvm

args=(
    -L "$REIMS_DIR/qemu-bundle/usr/local/share/qemu"
    -name macOS-Ventura-reims
    -enable-kvm
    -object "memory-backend-memfd,id=reims-ram,size=$RAM,share=on"
    -machine q35,memory-backend=reims-ram
    -global ICH9-LPC.disable_s3=1
    -global ICH9-LPC.disable_s4=1
    -cpu Skylake-Client,-hle,-rtm,kvm=on,vendor=GenuineIntel,+invtsc,vmware-cpuid-freq=on,+ssse3,+sse4.2,+popcnt,+avx,+avx2,+aes,+xsave,+xsaveopt,check
    -smp cores="$CPUS",sockets=1
    -m "$RAM"
    -device qemu-xhci,id=xhci
    -device usb-kbd,bus=xhci.0
    -device usb-tablet,bus=xhci.0
    -device isa-applesmc,osk="$OSK"
    -drive if=pflash,format=raw,readonly=on,file="$VM_DIR/OVMF_CODE_4M.fd"
    -drive if=pflash,format=raw,file="$VM_DIR/OVMF_VARS.fd"
    -smbios type=2
    -device ich9-ahci,id=sata
    -drive id=OpenCore,if=none,snapshot=on,format=qcow2,file="$VM_DIR/OpenCore.qcow2"
    -device ide-hd,bus=sata.2,drive=OpenCore
    -drive id=MacHDD,if=none,format=qcow2,file="$VM_DIR/macOS.qcow2"
    -device ide-hd,bus=sata.4,drive=MacHDD
    -netdev "user,id=net0,hostfwd=tcp::${SSH_PORT}-:22"
    -device vmxnet3,netdev=net0,id=net0,mac="$MAC_ADDR"
    -vga none
    -device pci-bridge,chassis_nr=5,id=pci.5,bus=pcie.0,addr=1e.0
    -device "reims-vgpu-pci,bus=pci.5,addr=00.0,romfile=$GOP_ROM,rombar=1"
    -vnc "127.0.0.1:$VNC_DISPLAY"
    -monitor "unix:$VM_DIR/monitor.sock,server,nowait"
    -serial "file:$VM_DIR/serial.log"
)

exec "$QEMU_BIN" "${args[@]}"
