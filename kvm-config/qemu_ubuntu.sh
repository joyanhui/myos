#!/usr/bin/env bash
set -e

#     https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img
#     国内镜像: https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cloud-images/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img
#     https://cloud-images.ubuntu.com/releases/26.04/release/ubuntu-26.04-server-cloudimg-amd64.img
#   ./kvm-config/qemu-ubuntu.sh             # 直接启动 cloud image
#   ./kvm-config/qemu-ubuntu.sh --graphic   # 启用图形窗口（cloud image 只有 tty）
#   ./kvm-config/qemu-ubuntu.sh --install   # 用 ISO 安装桌面版（需准备 ISO）
# SSH 转发: ssh ubuntu@localhost -p 2222

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

CLOUD_IMG="/home/nixos/kvm/ubuntu-server-cloudimg.qcow2"
CLOUD_IMG_URL="https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
CLOUD_IMG_URL_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/ubuntu-cloud-images/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
OVERLAY="/home/nixos/kvm/ubuntu-vm-overlay.qcow2"
SEED_ISO="/home/nixos/kvm/ubuntu-seed.iso"
INSTALL_ISO="/home/nixos/kvm/ubuntu-24.04.4-desktop-amd64.iso"
INSTALL_ISO_URL="https://releases.ubuntu.com/24.04/ubuntu-24.04.4-desktop-amd64.iso"
INSTALL_QCOW2="/home/nixos/kvm/ubuntu-install.qcow2"

make_seed_iso() {
    local tmpdir
    tmpdir="$(mktemp -d)"

    cat > "$tmpdir/user-data" <<'EOF'
#cloud-config
password: ubuntu
chpasswd: { expire: False }
ssh_pwauth: true
EOF

    cat > "$tmpdir/meta-data" <<'EOF'
instance-id: ubuntu-vm
local-hostname: ubuntu-vm
EOF

    nix-shell -p cdrkit --run \
        "genisoimage -output '$SEED_ISO' -volid cidata -joliet -rock '$tmpdir/user-data' '$tmpdir/meta-data'" \
        2>/dev/null

    rm -rf "$tmpdir"
}

SSH_INFO="  SSH: ssh ubuntu@localhost -p 2222  (密码: ubuntu)"

if [[ "${1:-}" == "--install" || "${1:-}" == "-install" ]]; then
    echo "启动 Ubuntu ISO 安装器..."
    echo "$SSH_INFO"
    if [[ ! -f "$INSTALL_ISO" ]]; then
        echo "缺少 ISO: $INSTALL_ISO"
        echo "下载地址: $INSTALL_ISO_URL"
        read -r -p "是否下载？[Y/n] " ans
        if [[ "${ans:-y}" =~ ^[Yy]$ ]]; then
            "${SCRIPT_DIR}/download.sh" \
                --url "$INSTALL_ISO_URL" \
                --output "$INSTALL_ISO"
        else
            echo "请准备 ISO 后重试" >&2
            exit 1
        fi
    fi
    if [[ ! -f "$INSTALL_QCOW2" ]]; then
        echo "创建磁盘镜像: $INSTALL_QCOW2 (64G)"
        qemu-img create -f qcow2 "$INSTALL_QCOW2" 64G
    fi

    exec qemu-system-x86_64 \
        -name ubuntu-install \
        -enable-kvm \
        -machine q35,accel=kvm \
        -cpu host \
        -smp cores=4 \
        -m 8G \
        -boot order=d \
        -drive file="${INSTALL_QCOW2}",if=virtio \
        -drive file="${INSTALL_ISO}",index=1,media=cdrom \
        -display gtk -device virtio-vga \
        -device qemu-xhci -device usb-tablet -device usb-kbd \
        -nic user,model=e1000e,hostfwd=tcp::2222-:22
fi

if [[ ! -f "$CLOUD_IMG" ]]; then
    echo "缺少 Cloud Image: $CLOUD_IMG"
    echo "下载地址: $CLOUD_IMG_URL"
    echo "国内镜像: $CLOUD_IMG_URL_MIRROR"
    read -r -p "是否下载？（将使用国内镜像）[Y/n] " ans
    if [[ "${ans:-y}" =~ ^[Yy]$ ]]; then
        "${SCRIPT_DIR}/download.sh" \
            --url "$CLOUD_IMG_URL_MIRROR" \
            --output "$CLOUD_IMG"
    else
        echo "请准备 Cloud Image 后重试" >&2
        exit 1
    fi
fi

if [[ ! -f "$OVERLAY" ]]; then
    echo "创建 overlay 快照..."
    qemu-img create -b "$CLOUD_IMG" -F qcow2 -f qcow2 "$OVERLAY"
fi

if [[ ! -f "$SEED_ISO" ]]; then
    echo "生成 cloud-init seed ISO..."
    make_seed_iso
fi

if [[ "${1:-}" == "--graphic" || "${1:-}" == "-graphic" ]]; then
    echo "启动 Ubuntu Cloud Image (图形模式)..."
    echo "$SSH_INFO"
    exec qemu-system-x86_64 \
        -name ubuntu-vm \
        -enable-kvm \
        -machine q35,accel=kvm \
        -cpu host \
        -smp cores=4 \
        -m 8G \
        -drive file="${OVERLAY}",if=virtio \
        -drive file="${SEED_ISO}",if=virtio,format=raw \
        -display gtk -device virtio-vga \
        -device qemu-xhci -device usb-tablet -device usb-kbd \
        -nic user,model=e1000e,hostfwd=tcp::2222-:22
fi

echo "启动 Ubuntu Cloud Image..."
echo "  串口: Ctrl+A 然后按 C 进入 QEMU monitor"
echo "$SSH_INFO"

exec qemu-system-x86_64 \
    -name ubuntu-vm \
    -enable-kvm \
    -machine type=q35,accel=kvm \
    -cpu host \
    -smp cores=4 \
    -m 8G \
    -nographic \
    -drive if=virtio,format=qcow2,file="${OVERLAY}" \
    -drive if=virtio,format=raw,file="${SEED_ISO}" \
    -netdev id=net00,type=user,hostfwd=tcp::2222-:22 \
    -device virtio-net-pci,netdev=net00
