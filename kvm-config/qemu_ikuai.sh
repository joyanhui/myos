#!/usr/bin/env bash
set -e

#   qemu-img create -f qcow2 /home/nixos/kvm/ikuai.qcow2 32G

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

QCOW2="/home/nixos/kvm/ikuai.qcow2"
ISO="/home/nixos/kvm/iKuai8_x64_4.0.303_Build202606251647.iso"
ISO_URL="https://patch.ikuai8.com/3.x/iso/iKuai8_x64_4.0.303_Build202606251647.iso"

if [[ ! -f "${ISO}" ]]; then
    echo "缺少 ISO: ${ISO}"
    echo "下载地址: ${ISO_URL}"
    read -r -p "是否下载？[Y/n] " ans
    if [[ "${ans:-y}" =~ ^[Yy]$ ]]; then
        "${SCRIPT_DIR}/download.sh" \
            --url "${ISO_URL}" \
            --output "${ISO}"
    else
        echo "请准备 ISO 后重试" >&2
        exit 1
    fi
fi

ISO_ARG=()
BOOT_ORDER="c"
if [[ "${1:-}" == "--install" || "${1:-}" == "-install" ]]; then
    ISO_ARG=(-drive file="${ISO}",index=1,media=cdrom)
    BOOT_ORDER="d"
fi

cleanup() {
    sudo ip link delete tap0 2>/dev/null || true
}
trap cleanup EXIT

sudo ip link delete tap0 2>/dev/null || true
sudo ip tuntap add dev tap0 mode tap user "$(whoami)"
sudo ip link set tap0 up
sudo ip addr add 192.168.10.1/24 dev tap0
sudo ip addr del 192.168.10.1/24 dev tap0
sudo ip addr add 192.168.9.2/24 dev tap0

exec qemu-system-x86_64 \
    -M q35,usb=on,acpi=on,hpet=off \
    -m 4G -smp cores=4 -accel kvm \
    -boot order="${BOOT_ORDER}" \
    -drive file="${QCOW2}",if=virtio \
    "${ISO_ARG[@]}" \
    -device usb-tablet -device VGA,vgamem_mb=256 -monitor stdio \
    -nic tap,ifname=tap0,script=no,downscript=no,model=e1000,mac=98:6A:5E:44:59:11 \
    -nic user,model=e1000,mac=A4:99:14:44:14:22,hostfwd=tcp::8081-:80 \
    -nic user,model=e1000,mac=50:00:F8:6A:F0:33 \
    -nic user,model=e1000,mac=B0:48:32:04:AC:44
