#!/usr/bin/env bash
set -e

#   https://fw0.koolcenter.com/iStoreOS/x86_64/istoreos-24.10.7-2026060510-x86-64-squashfs-combined.img.gz
#   ./kvm-config/qemu_openwrt_istore.sh                      # 串口控制台
#   ./kvm-config/qemu_openwrt_istore.sh --graphic            # GTK 图形窗口
#   ./kvm-config/qemu_openwrt_istore.sh --host-ip 10.0.0.2   # 指定宿主 tap0 IP

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

DISK_FILE="/home/nixos/kvm/istoreos-24.10.7-2026060510-x86-64-squashfs-combined.qcow2"
DOWNLOAD_URL="https://fw0.koolcenter.com/iStoreOS/x86_64/istoreos-24.10.7-2026060510-x86-64-squashfs-combined.img.gz"
DOWNLOAD_ARCHIVE="${DISK_FILE%.qcow2}.img.gz"
DOWNLOAD_EXTRACT="gz"
DOWNLOAD_CONVERT="qcow2"
DOWNLOAD_KEEP="--keep"

TAP_IF="tap0"
OPENWRT_LAN_IP="10.0.0.1"
HOST_TAP_IP="10.0.0.2"
LAN_CIDR="10.0.0.0/24"
HOST_FWD_PORT="8081"
SOCAT_PID_FILE="/tmp/qemu_openwrt_socat.pid"
GRAPHIC=0

QCOW2="${DISK_FILE}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --graphic|-graphic)
            GRAPHIC=1
            shift
            ;;
        --host-ip)
            HOST_TAP_IP="${2:?缺少 --host-ip 参数}"
            shift 2
            ;;
        --lan-cidr)
            LAN_CIDR="${2:?缺少 --lan-cidr 参数}"
            shift 2
            ;;
        --hostfwd-port)
            HOST_FWD_PORT="${2:?缺少 --hostfwd-port 参数}"
            shift 2
            ;;
        *)
            echo "未知参数: $1" >&2
            exit 2
            ;;
    esac
done

if [[ ! -f "${DISK_FILE}" ]]; then
    echo "缺少虚拟磁盘: ${DISK_FILE}"
    echo "下载地址: ${DOWNLOAD_URL}"
    read -r -p "是否下载、解压并转换为 qcow2？[Y/n] " ans
    if [[ "${ans:-y}" =~ ^[Yy]$ ]]; then
        "${SCRIPT_DIR}/download.sh" \
            --url "${DOWNLOAD_URL}" \
            --output "${DISK_FILE}" \
            --archive "${DOWNLOAD_ARCHIVE}" \
            --extract "${DOWNLOAD_EXTRACT}" \
            --convert "${DOWNLOAD_CONVERT}" \
            ${DOWNLOAD_KEEP}
    else
        echo "请准备磁盘文件后重试" >&2
        exit 1
    fi
fi

cleanup() {
    echo ""
    echo "清理: 关闭 QEMU/socat，删除 ${TAP_IF}..."
    sudo pkill -9 qemu-system-x86_64 2>/dev/null || true
    if [[ -f "${SOCAT_PID_FILE}" ]]; then
        kill "$(<"${SOCAT_PID_FILE}")" 2>/dev/null || true
        rm -f "${SOCAT_PID_FILE}"
    fi
    sleep 1
    sudo ip link delete "${TAP_IF}" 2>/dev/null || true
}
trap cleanup EXIT

echo "==> 清理残留 QEMU 进程..."
sudo pkill -9 qemu-system-x86_64 2>/dev/null || true

if command -v lsof &>/dev/null; then
    for i in $(seq 1 5); do
        if ! sudo lsof "${QCOW2}" >/dev/null 2>&1; then
            break
        fi
        echo "    等待磁盘锁释放... ($i/5)"
        sleep 1
    done
    if sudo lsof "${QCOW2}" >/dev/null 2>&1; then
        echo "警告: ${QCOW2} 仍被占用，尝试强制释放..."
        sudo lsof -t "${QCOW2}" 2>/dev/null | xargs -r sudo kill -9 2>/dev/null || true
        sleep 1
    fi
fi

echo "==> 配置 ${TAP_IF} 网络..."
if ip route show "${LAN_CIDR}" | grep -qv "dev ${TAP_IF}"; then
    echo "错误: 宿主机已存在 ${LAN_CIDR} 路由，无法稳定直连 iStoreOS ${OPENWRT_LAN_IP}。" >&2
    ip route show "${LAN_CIDR}" >&2
    echo "请改 iStoreOS LAN 网段，或用 http://localhost:${HOST_FWD_PORT}/ 访问。" >&2
    exit 1
fi
sudo ip link delete "${TAP_IF}" 2>/dev/null || true
sudo ip tuntap add dev "${TAP_IF}" mode tap user "$(whoami)"
sudo ip link set "${TAP_IF}" up
sudo ip addr add "${HOST_TAP_IP}/24" dev "${TAP_IF}"
if [[ -f "${SOCAT_PID_FILE}" ]]; then
    kill "$(<"${SOCAT_PID_FILE}")" 2>/dev/null || true
    rm -f "${SOCAT_PID_FILE}"
fi
if command -v socat >/dev/null 2>&1; then
    socat "TCP-LISTEN:${HOST_FWD_PORT},bind=127.0.0.1,fork,reuseaddr" "TCP:${OPENWRT_LAN_IP}:80" &
    echo "$!" > "${SOCAT_PID_FILE}"
else
    echo "警告: 未找到 socat，http://localhost:${HOST_FWD_PORT}/ 转发不可用。" >&2
fi

QEMU_ARGS_COMMON=(
    -M q35,usb=on,acpi=on,hpet=off
    -m 4G -smp cores=4 -accel kvm
    -drive file="${QCOW2}",format=qcow2,if=virtio
    -nic tap,ifname="${TAP_IF}",script=no,downscript=no,model=e1000,mac=98:6A:5E:44:11:11
    -nic user,model=e1000,mac=A4:99:14:44:22:22
)

if [[ "${GRAPHIC}" == "1" ]]; then
    echo "启动 iStoreOS (图形模式)..."
    echo "  Web 直连: http://${OPENWRT_LAN_IP}/"
    echo "  Web 转发: http://localhost:${HOST_FWD_PORT}/"
    qemu-system-x86_64 \
        "${QEMU_ARGS_COMMON[@]}" \
        -device usb-tablet -device VGA,vgamem_mb=256 \
        -display gtk
    exit $?
fi

echo "启动 iStoreOS..."
echo "  串口: Ctrl+A 然后按 C 进入 QEMU monitor"
echo "  Web 直连: http://${OPENWRT_LAN_IP}/"
echo "  Web 转发: http://localhost:${HOST_FWD_PORT}/"
echo "  登录: 回车后输入 root（无密码）"

qemu-system-x86_64 \
    "${QEMU_ARGS_COMMON[@]}" \
    -nographic
