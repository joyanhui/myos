#!/usr/bin/env bash
set -uo pipefail

#   ./kvm-config/qemu_win11_passthrough.sh          # 直通运行（需退出桌面到 TTY）
#   ./kvm-config/qemu_win11_passthrough.sh --check  # 仅预检 + 打印 QEMU 命令（无需 root）

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FW_DIR="${SCRIPT_DIR}/firmware"

ROM_MODE="none"
declare -A ROM_FILES
ROM_FILES["1002:1681"]="vbios_6800h.bin"
ROM_FILES["1002:1640"]="AMDGopDriver_6800H.rom"

DEVICES_PASSTHROUGH=(
  "1002:1681 amdgpu"
  "1002:1640 snd_hda_intel"
)

DEVICES_PERMANENT=(
  # "10ec:8168 r8169             # Realtek RTL8111/8168 网卡（归还后会触发宿主机重启）"
)

declare -A ADDR_FALLBACK
ADDR_FALLBACK["1002:1681"]="0000:75:00.0"
ADDR_FALLBACK["1002:1640"]="0000:75:00.1"

INPUT_DEVICES=(
  "/dev/input/by-path/platform-i8042-serio-0-event-kbd"
  "/dev/input/by-path/platform-AMDI0010:00-event-mouse"
)

_find_pci() {
  local vid_did="$1"
  lspci -Dn 2>/dev/null | awk -v id="$vid_did" '$3 == id {print $1; exit}'
}

_validate_rom() {
  local f="$1"
  [[ -f "$f" ]] || { echo "    错误: ROM 文件不存在: $f"; return 1; }
  local magic
  magic=$(od -An -tx1 -N2 "$f" | tr -d ' \n')
  if [[ "$magic" != "55aa" ]]; then
    echo "    警告: ${f##*/} 不是合法 Option ROM（缺 55aa 魔数）"
    return 1
  fi
  local pcir_off pcir_sig
  pcir_off=$(od -An -tu2 -j24 -N2 --endian=little "$f" | tr -d ' ')
  pcir_sig=$(dd if="$f" bs=1 skip="$pcir_off" count=4 2>/dev/null)
  if [[ "$pcir_sig" != "PCIR" ]]; then
    echo "    警告: ${f##*/} 缺少 PCIR 结构（0x18 指针指向 $pcir_off 处: $pcir_sig）"
    return 1
  fi
  return 0
}

_parse_dev() {
  local entry="$1"
  local id_var="$2" drv_var="$3"
  read -r vid_did drv _ <<< "$entry"
  printf -v "$id_var" "%s" "$vid_did"
  printf -v "$drv_var" "%s" "$drv"
}

resolve_all() {
  local entries=("${DEVICES_PASSTHROUGH[@]}" "${DEVICES_PERMANENT[@]}")
  RESOLVED_ADDR=()
  RESOLVED_ID=()
  RESOLVED_DRV=()
  RESOLVED_PERM=()
  local -i fail=0 idx=0
  for entry in "${entries[@]}"; do
    local vid_did drv addr
    _parse_dev "$entry" vid_did drv
    addr=$(_find_pci "$vid_did")
    if [[ -z "$addr" ]]; then
      addr="${ADDR_FALLBACK[$vid_did]:-}"
      if [[ -z "$addr" ]]; then
        echo "  错误: 设备 $vid_did 未发现且无回退地址" >&2
        fail=1
        continue
      fi
      echo "  警告: $vid_did 自动发现失败，回退静态地址 $addr（请核对 lspci -Dn）" >&2
    fi
    if [[ ! -d "/sys/bus/pci/devices/$addr" ]]; then
      echo "  错误: 发现的地址 $addr（$vid_did）在 sysfs 中不存在" >&2
      fail=1
      continue
    fi
    RESOLVED_ADDR+=("$addr")
    RESOLVED_ID+=("$vid_did")
    RESOLVED_DRV+=("$drv")
    if [[ $idx -lt ${#DEVICES_PASSTHROUGH[@]} ]]; then
      RESOLVED_PERM+=(0)
    else
      RESOLVED_PERM+=(1)
    fi
    ((idx++))
  done
  return $fail
}

bind_all() {
  local -i i
  for i in "${!RESOLVED_ADDR[@]}"; do
    local addr="${RESOLVED_ADDR[$i]}" vid_did="${RESOLVED_ID[$i]}" driver="${RESOLVED_DRV[$i]}"
    local vendor_id="${vid_did%%:*}" device_id="${vid_did##*:}"

    local current_driver
    current_driver=$(basename "$(readlink "/sys/bus/pci/devices/$addr/driver" 2>/dev/null)" 2>/dev/null || true)

    if [[ "$current_driver" == "vfio-pci" ]]; then
      echo "  $addr 已在 vfio-pci，跳过"
      continue
    fi

    echo "  绑定 $addr（$vid_did，$current_driver → vfio-pci）..."
    if [[ -n "$current_driver" ]]; then
      echo "$addr" > "/sys/bus/pci/drivers/$current_driver/unbind" 2>/dev/null \
        || { echo "    错误: 从 $current_driver 解绑失败（设备可能仍被占用）" >&2; return 1; }
    fi
    echo "$vendor_id $device_id" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null
    sleep 0.3

    local after
    after=$(basename "$(readlink "/sys/bus/pci/devices/$addr/driver" 2>/dev/null)" 2>/dev/null || true)
    if [[ "$after" != "vfio-pci" ]]; then
      echo "    错误: $addr 绑定后驱动为 $after，不是 vfio-pci" >&2
      return 1
    fi
    echo "  完成"
  done
  return 0
}

unbind_all() {
  local -i i
  for i in "${!RESOLVED_ID[@]}"; do
    local vid_did="${RESOLVED_ID[$i]}" vendor_id device_id
    vendor_id="${vid_did%%:*}" device_id="${vid_did##*:}"
    echo "$vendor_id $device_id" > /sys/bus/pci/drivers/vfio-pci/remove_id 2>/dev/null || true
  done

  for i in "${!RESOLVED_ADDR[@]}"; do
    [[ "${RESOLVED_PERM[$i]}" == "1" ]] && continue
    local addr="${RESOLVED_ADDR[$i]}" driver="${RESOLVED_DRV[$i]}"
    local pci_dev_path="/sys/bus/pci/devices/$addr"

    if [[ ! -d "$pci_dev_path" ]]; then
      echo "  $addr 设备不存在，跳过"
      continue
    fi

    local current_driver
    current_driver=$(basename "$(readlink "$pci_dev_path/driver" 2>/dev/null)" 2>/dev/null || true)

    if [[ "$current_driver" != "vfio-pci" ]]; then
      echo "  $addr 不在 vfio-pci 中，跳过"
      continue
    fi

    echo "  归还 $addr 给 $driver..."
    echo 1 > "$pci_dev_path/remove" 2>/dev/null || true
  done

  echo 1 > /sys/bus/pci/rescan 2>/dev/null || true

  local gpu="${RESOLVED_ADDR[0]:-}"
  if [[ -n "$gpu" && -d "/sys/bus/pci/devices/$gpu" ]]; then
    local after
    after=$(basename "$(readlink "/sys/bus/pci/devices/$gpu/driver" 2>/dev/null)" 2>/dev/null || true)
    echo "  GPU $gpu 当前驱动: ${after:-无}"
    [[ "$after" == "amdgpu" ]] && echo "  归还成功" || echo "  警告: GPU 未回到 amdgpu，需重启宿主机恢复"
  fi
  echo "  所有动态设备已归还"
}

build_qemu_devices() {
  local -n arr="$1"

  declare -A group_slot
  declare -A group_count
  local qemu_slot=16
  local -i i
  for i in "${!RESOLVED_ADDR[@]}"; do
    local addr="${RESOLVED_ADDR[$i]}"
    local bus_slot="${addr%.*}"
    if [[ -z "${group_slot[$bus_slot]:-}" ]]; then
      group_slot["$bus_slot"]=$qemu_slot
      ((qemu_slot++))
    fi
    group_count["$bus_slot"]=$(( ${group_count[$bus_slot]:-0} + 1 ))
  done

  for i in "${!RESOLVED_ADDR[@]}"; do
    local addr="${RESOLVED_ADDR[$i]}" vid_did="${RESOLVED_ID[$i]}"
    local bus_slot="${addr%.*}"
    local func="${addr##*.}"
    local short_addr="${addr#0000:}"

    local opts="vfio-pci,host=${short_addr}"
    local slot=${group_slot[$bus_slot]}
    local count=${group_count[$bus_slot]}

    if [[ "$count" -gt 1 ]]; then
      opts+=",addr=0x${slot}.${func}"
      if [[ "$func" == "0" ]]; then
        opts+=",multifunction=on"
      fi
    fi

    local class
    class=$(lspci -s "$addr" -nn 2>/dev/null | grep -o '\[03[0-9a-f][0-9a-f]\]' || true)
    if [[ -n "$class" ]]; then
      opts+=",x-vga=on"
    fi

    local rom="${ROM_FILES[$vid_did]:-}"
    if [[ "$ROM_MODE" == "none" ]]; then
      rom=""
    elif [[ "$ROM_MODE" == "gop" && "$vid_did" == "1002:1681" ]]; then
      rom="AMDGopDriver_6800H.rom"
    fi
    if [[ -n "$rom" ]]; then
      opts+=",romfile=${FW_DIR}/${rom}"
    fi

    arr+=(-device "$opts")
  done
}

build_input_devices() {
  local -n arr="$1"
  for evdev in "${INPUT_DEVICES[@]}"; do
    if [[ -e "$evdev" ]]; then
      local name_id="${evdev##*/}"
      name_id="${name_id//-/_}"
      name_id="${name_id//:/_}"
      arr+=(-object "input-linux,id=${name_id},evdev=${evdev},grab_all=on,repeat=on")
    fi
  done
}

has_gpu_passthrough() {
  local -i i
  for i in "${!RESOLVED_ADDR[@]}"; do
    local addr="${RESOLVED_ADDR[$i]}"
    local class
    class=$(lspci -s "$addr" -nn 2>/dev/null | grep -o '\[03[0-9a-f][0-9a-f]\]' || true)
    if [[ -n "$class" ]]; then
      return 0
    fi
  done
  return 1
}

CHECK_MODE=0
if [[ "${1:-}" == "--check" ]]; then
  CHECK_MODE=1
fi

if [[ $CHECK_MODE -eq 0 && ( -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ) ]]; then
  cat >&2 <<'EOF'
错误：检测到当前在图形桌面中运行

直通核心显卡(Radeon 680M) 需要先退出桌面，因为正在使用的 GPU 无法直接解绑。
请按以下步骤操作：

  1. 退出当前桌面（Niri）：
     pkill niri
     # 或使用 Mod+Shift+E 等快捷键退出

  2. 在 TTY 中重新运行本脚本：
./kvm-config/qemu_win11_passthrough.sh

  3. VM 关闭后，重新启动桌面：
     niri-session
EOF
  exit 1
fi

if [[ $EUID -ne 0 && $CHECK_MODE -eq 0 ]]; then
  exec sudo "$0" "$@"
fi

if [[ $CHECK_MODE -eq 0 ]]; then
  trap unbind_all EXIT
fi

echo "==== 预检 ===="

if [[ ! -d /sys/kernel/iommu_groups ]] || [[ -z "$(ls -A /sys/kernel/iommu_groups 2>/dev/null)" ]]; then
  echo "  错误: IOMMU 未启用（需要 amd_iommu=on iommu=pt，见 machine/tb_amd/default.nix）" >&2
  exit 1
fi
echo "  IOMMU: 已启用"

if ! ls /dev/vfio/vfio >/dev/null 2>&1; then
  echo "  警告: /dev/vfio/vfio 不存在，尝试加载模块..."
  modprobe vfio-pci 2>/dev/null || true
  ls /dev/vfio/vfio >/dev/null 2>&1 || { echo "  错误: vfio 不可用" >&2; exit 1; }
fi
echo "  vfio: 可用"

echo "  解析设备..."
if ! resolve_all; then
  echo "  错误: 设备解析失败，请用 lspci -Dn 核对设备 ID" >&2
  exit 1
fi
for i in "${!RESOLVED_ADDR[@]}"; do
  printf "    %s  %s  (%s)\n" "${RESOLVED_ADDR[$i]}" "${RESOLVED_ID[$i]}" "${RESOLVED_DRV[$i]}"
done

if [[ "$ROM_MODE" != "none" ]]; then
  echo "  ROM 校验（ROM_MODE=$ROM_MODE）:"
  for vid_did in "${!ROM_FILES[@]}"; do
    rom="${ROM_FILES[$vid_did]}"
    if [[ "$ROM_MODE" == "gop" && "$vid_did" == "1002:1681" ]]; then
      rom="AMDGopDriver_6800H.rom"
    fi
    _validate_rom "${FW_DIR}/${rom}"
  done
fi

for f in OVMF.fd OVMF_VARS.fd; do
  [[ -f "${FW_DIR}/$f" ]] || { echo "  错误: 缺少 ${FW_DIR}/$f" >&2; exit 1; }
done
DISK="/mnt/NVME_NTFS/win11.vhd"
[[ -f "$DISK" ]] || { echo "  错误: 磁盘不存在 $DISK" >&2; exit 1; }
echo "  固件/磁盘: OK"

QEMU_OPTS=()
build_qemu_devices QEMU_OPTS

if has_gpu_passthrough; then
  echo "检测到 GPU 直通，使用直通显示模式"
  DISPLAY_OPTS=("-display" "none" "-vga" "none")
  INPUT_OPTS=()
  build_input_devices INPUT_OPTS
else
  DISPLAY_OPTS=("-display" "gtk" "-device" "virtio-vga")
  INPUT_OPTS=("-device" "qemu-xhci" "-device" "usb-tablet" "-device" "usb-kbd")
fi

#   -drive file=/mnt/DATA128G/Core_File/ISO/HotPE-V2.8.251018.iso,media=cdrom,index=1
#   -drive file=/mnt/DATA128G/Core_File/ISO/virtio-win-0.1.285.iso,media=cdrom,index=2

QEMU_LOG="/tmp/qemu_win11_passthrough.log"
echo "QEMU 日志: $QEMU_LOG"

if [[ $CHECK_MODE -eq 1 ]]; then
  echo ""
  echo "==== 预检通过，以下为将执行的 QEMU 命令（未执行） ===="
  printf 'qemu-system-x86_64 %s\n' \
    "-name win11-kvm -enable-kvm" \
    "-machine q35,accel=kvm,smm=on" \
    "-cpu host,kvm=off,hv_relaxed,hv_vapic,hv_spinlocks=0x1fff,hv_vpindex,hv_time,hv_stimer,hv_synic,hv_frequencies,hv_runtime,hv_tlbflush,hv_ipi" \
    "-smp cores=8 -m 12G" \
    "${DISPLAY_OPTS[*]}" \
    "${INPUT_OPTS[*]}" \
    "${QEMU_OPTS[*]}"
  exit 0
fi

unbind_framebuffer() {
  for fb in efi-framebuffer simple-framebuffer; do
    local fbdev
    for fbdev in /sys/bus/platform/drivers/$fb/*/; do
      fbdev="${fbdev%/}"
      if [[ -d "$fbdev" ]]; then
        echo "  解绑 framebuffer: $(basename "$fbdev")"
        echo "$(basename "$fbdev")" > "/sys/bus/platform/drivers/$fb/unbind" 2>/dev/null || true
      fi
    done
  done
}
unbind_framebuffer

echo "正在绑定设备到 vfio-pci..."
bind_all || { echo "错误: 设备绑定失败，已中止" >&2; exit 1; }
sleep 1

qemu-system-x86_64 \
  -name win11-kvm \
  -enable-kvm \
  -machine q35,accel=kvm,smm=on \
  -cpu host,kvm=off,hv_relaxed,hv_vapic,hv_spinlocks=0x1fff,hv_vpindex,hv_time,hv_stimer,hv_synic,hv_frequencies,hv_runtime,hv_tlbflush,hv_ipi \
  -smp cores=8 \
  -m 12G \
  -global kvm-pit.lost_tick_policy=discard \
  "${DISPLAY_OPTS[@]}" \
  "${INPUT_OPTS[@]}" \
  -drive "if=pflash,format=raw,readonly=on,file=${FW_DIR}/OVMF.fd" \
  -drive "if=pflash,format=raw,file=${FW_DIR}/OVMF_VARS.fd" \
  -drive "if=none,id=system,file=/mnt/NVME_NTFS/win11.vhd,format=vpc,cache=writeback,aio=io_uring" \
  -device nvme,drive=system,serial=win11vhd0 \
  -nic user,hostfwd=tcp::3391-:3389,model=e1000e \
  "${QEMU_OPTS[@]}" 2>&1 | tee "$QEMU_LOG"
