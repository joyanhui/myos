#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FW_DIR="${SCRIPT_DIR}/firmware"

has_display() {
  if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
    local wl_socket="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/${WAYLAND_DISPLAY}"
    [[ -S "$wl_socket" ]] && return 0
  fi
  if [[ -n "${DISPLAY:-}" ]]; then
    local x11_socket="/tmp/.X11-unix/X${DISPLAY#*:}"
    [[ -S "$x11_socket" ]] && return 0
  fi
  return 1
}

if has_display; then
  echo "检测到桌面环境，启用图形显示"
  DISPLAY_OPTS=(
    -display gtk,gl=on
    -device virtio-vga-gl,hostmem=2G,blob=true,venus=true
  )
  INPUT_OPTS=("-device" "qemu-xhci" "-device" "usb-tablet" "-device" "usb-kbd")
else
  echo "无桌面环境，启用 headless 模式（RDP 访问端口 3391）"
  DISPLAY_OPTS=(
    -display none
    -vga none
    -device virtio-vga,hostmem=2G
  )
  INPUT_OPTS=("-device" "qemu-xhci" "-device" "usb-tablet" "-device" "usb-kbd")
fi

sudo -E qemu-system-x86_64 \
  -name win11-kvm \
  -enable-kvm \
  -machine q35,accel=kvm,smm=on \
  -cpu host,hv_relaxed,hv_vapic,hv_spinlocks=0x1fff,hv_vpindex,hv_time,hv_stimer,hv_synic,hv_frequencies,hv_runtime,hv_tlbflush,hv_ipi \
  -smp cores=8 \
  -m 12G \
  "${DISPLAY_OPTS[@]}" \
  "${INPUT_OPTS[@]}" \
  -drive "if=pflash,format=raw,readonly=on,file=${FW_DIR}/OVMF.fd" \
  -drive "if=pflash,format=raw,file=${FW_DIR}/OVMF_VARS.fd" \
  -drive "if=none,id=system,file=/mnt/NVME_NTFS/win11.vhd,format=vpc,cache=writeback,aio=io_uring" \
  -device nvme,drive=system,serial=win11vhd0 \
  -drive file=/mnt/DATA128G/Core_File/ISO/HotPE-V2.8.251018.iso,media=cdrom,index=1 \
  -drive file=/mnt/DATA128G/Core_File/ISO/virtio-win-0.1.285.iso,media=cdrom,index=2 \
  -nic user,hostfwd=tcp::3391-:3389,model=e1000e
