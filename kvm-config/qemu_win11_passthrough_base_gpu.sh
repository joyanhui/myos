#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FW="$ROOT/kvm-config/firmware"
DISK="/mnt/NVME_NTFS/win11.vhd"
GPU_PHASE="${GPU_PHASE:-0}"
GPU_ROM_MODE="${GPU_ROM_MODE:-vbios}"

GPU_OPTS=()
if [[ "$GPU_PHASE" == "1" ]]; then
  GPU_OPTS=(
    -device vfio-pci,host=0000:75:00.0,addr=0x16.0,multifunction=on,x-vga=on,romfile="$FW/vbios_6800h.bin"
    -device vfio-pci,host=0000:75:00.1,addr=0x16.1
  )
  if [[ "$GPU_ROM_MODE" == "gop" ]]; then
    GPU_OPTS=(
      -device vfio-pci,host=0000:75:00.0,addr=0x16.0,multifunction=on,x-vga=on
      -device vfio-pci,host=0000:75:00.1,addr=0x16.1,romfile="$FW/AMDGopDriver_6800H.rom"
    )
  elif [[ "$GPU_ROM_MODE" == "both" ]]; then
    GPU_OPTS=(
      -device vfio-pci,host=0000:75:00.0,addr=0x16.0,multifunction=on,x-vga=on,romfile="$FW/vbios_6800h.bin"
      -device vfio-pci,host=0000:75:00.1,addr=0x16.1,romfile="$FW/AMDGopDriver_6800H.rom"
    )
  fi
fi

exec sudo -n qemu-system-x86_64 \
  -name win11-gpu-validation \
  -monitor unix:/tmp/win11-gpu-validation.monitor,server=on,wait=off \
  -enable-kvm \
  -machine q35,accel=kvm,smm=on \
  -cpu host,kvm=off,hv_relaxed,hv_vapic,hv_spinlocks=0x1fff,hv_vpindex,hv_time,hv_stimer,hv_synic,hv_frequencies,hv_runtime,hv_tlbflush,hv_ipi \
  -smp cores=8 \
  -m 12G \
  -display none \
  -vga none \
  -device virtio-vga \
  -device qemu-xhci \
  -device usb-tablet \
  -device usb-kbd \
  -drive "if=pflash,format=raw,readonly=on,file=$FW/OVMF.fd" \
  -drive "if=pflash,format=raw,file=$FW/OVMF_VARS.fd" \
  -drive "if=none,id=system,file=$DISK,format=vpc,cache=writeback,aio=io_uring" \
  -device nvme,drive=system,serial=win11vhd0 \
  -nic user,hostfwd=tcp::3391-:3389,model=e1000e \
  "${GPU_OPTS[@]}"
