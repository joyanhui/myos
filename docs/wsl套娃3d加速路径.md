# WSL 内 KVM Linux 的 3D 加速实现与验证

## 结论

**可以。** 在 WSL2 中运行的 KVM Linux 来宾，可以通过 QEMU 的 `virtio-vga-gl` / virgl 路径使用 3D 加速，并经 WSLg 图形后端呈现。

这不是把宿主 AMD GPU 原生 PCI 直通给来宾。来宾使用 Virtio 虚拟 GPU；来宾 OpenGL 命令经 Mesa virgl 路径处理，再由 QEMU 的 GL 显示后端接入 WSLg。只启用 KVM，或只让来宾窗口显示出来，都不能证明 3D 加速已启用。

## 图形数据路径

```text
来宾 Linux 图形应用
  → 来宾 Mesa / OpenGL
  → virtio-gpu DRM 设备
  → QEMU virtio-vga-gl / virgl
  → QEMU GTK GL 显示后端
  → WSLg / Weston
  → Windows D3D12 GPU 后端
  → AMD Radeon GPU
```

KVM 提供虚拟机 CPU 加速；`virtio-vga-gl`/virgl 提供来宾 3D 图形设备。两者负责不同工作。

## 前提条件

- Windows 已启用 WSL2 与 Virtual Machine Platform。
- WSL 中已能使用 KVM，`/dev/kvm` 可打开。
- WSLg 可用，WSL 主机的 Mesa 能选择 D3D12 驱动。
- QEMU 含有 `virtio-vga-gl` 和 GTK GL 显示支持。
- 来宾安装 Virtio GPU/Mesa 驱动、Xorg 或其他图形环境、`mesa-utils`。

## 1. 验证 WSLg 主机 GPU 基线

在 WSL Debian 中安装检查工具（如尚未安装）：

```bash
sudo apt update
sudo apt install -y mesa-utils
```

检查 WSLg D3D12 渲染器：

```bash
GALLIUM_DRIVER=d3d12 glxinfo -B
```

本机结果：

```text
OpenGL renderer string: D3D12 (AMD Radeon(TM) Graphics)
Accelerated: yes
```

这是 WSL Debian 主机环境的验证，不代表来宾已经启用加速。

## 2. 检查 QEMU 图形后端

查看 QEMU 版本和可用设备：

```bash
qemu-system-x86_64 --version
qemu-system-x86_64 -device help | grep -E 'virtio-vga-gl|virtio-gpu-gl'
qemu-system-x86_64 -display help
```

QEMU 需要支持 Virtio GPU 的 GL 设备，并能在 WSLg 会话中创建 GL 显示上下文。

## 3. 以 KVM 和 virgl 启动 Linux 来宾

以下为启动参数示例；将镜像路径替换为自己的来宾磁盘：

```bash
qemu-system-x86_64 \
  -machine accel=kvm \
  -cpu host \
  -m 4G \
  -smp 4 \
  -drive file=guest.qcow2,if=virtio,format=qcow2 \
  -device virtio-vga-gl \
  -display gtk,gl=on \
  -nic user
```

参数作用：

- `-machine accel=kvm -cpu host` 使用 KVM 加速 CPU 虚拟化。
- `-device virtio-vga-gl` 向来宾提供带 3D 支持的 Virtio GPU。
- `-display gtk,gl=on` 让 QEMU 的 GL 显示后端连接到 WSLg。
- 实际环境可能还需要 QEMU 的 GTK/GL 运行依赖及 WSLg 图形会话。

## 4. 在来宾中验证虚拟 GPU

在来宾 Linux 安装 Mesa/Xorg 检查组件，例如 Debian：

```bash
sudo apt update
sudo apt install -y xserver-xorg-core xinit mesa-utils
```

确认设备与 DRM render node：

```bash
lspci -nn | grep -iE 'vga|display|3d'
ls -l /dev/dri
```

本次来宾检查到 Virtio 1.0 GPU `[1af4:1050]` 和 `/dev/dri/renderD128`。这证明虚拟 GPU 设备已传给来宾，但还需检查实际 OpenGL renderer。

## 5. 在来宾中验证 OpenGL renderer

在来宾图形会话中运行：

```bash
glxinfo -B
```

本次验证关键输出：

```text
direct rendering: Yes
Accelerated: yes
OpenGL renderer string: virgl (LLVMPIPE (LLVM 19.1.7, 256 bits))
```

`virgl` 表明来宾通过 Virtio/virgl 图形路径执行 OpenGL。`Accelerated: yes` 是 Mesa 给出的加速标记。renderer 字符串中包含 `LLVMPIPE` 并不等于这次测试退化成纯 CPU 软件渲染；应结合 QEMU 配置、来宾设备、DRM 节点和 GLX 输出综合确认。

可再运行短时 OpenGL 测试：

```bash
timeout 5s glxgears -info
```

本次测试成功创建 OpenGL 4.3 上下文，报告：

```text
GL_RENDERER = virgl (LLVMPIPE (LLVM 19.1.7, 256 bits))
GL_VERSION  = 4.3 (Compatibility Profile) Mesa 25.0.7-2+deb13u1
GL_VENDOR   = Mesa
```

## 已验证结果

本次端到端测试使用 Debian 13 来宾：

- 来宾枚举到 `Red Hat, Inc. Virtio 1.0 GPU [1af4:1050]`。
- 来宾存在 `/dev/dri/renderD128`。
- 来宾启动 Xorg 后，`glxinfo -B` 返回 `direct rendering: Yes` 与 `Accelerated: yes`。
- OpenGL renderer 为 `virgl (LLVMPIPE (LLVM 19.1.7, 256 bits))`。
- `glxgears` 成功创建 GL 上下文，报告 OpenGL 4.3 与 virgl renderer。
- WSL 主机基线为 `D3D12 (AMD Radeon(TM) Graphics)`，`Accelerated: yes`。

## 限制与诊断原则

- 这是 Virtio GPU/virgl 的虚拟化 3D 路径，不是 AMD GPU 原生 PCI 直通。
- `glxinfo` 必须在来宾的实际 X/Wayland 图形会话中运行；仅从 SSH shell 执行可能因没有 `DISPLAY` 而失败。
- QEMU 窗口能打开只证明显示路径启动，不足以证明来宾 OpenGL 加速。
- `/dev/dri/renderD128` 存在只证明来宾有 DRM render node，仍须检查来宾 `glxinfo -B` 和实际 OpenGL 应用。
- WSLg 主机的 D3D12 renderer 输出不能替代来宾 renderer 输出。
- 不要把来宾 virgl 与 WSL Debian 主机直接运行的 D3D12 renderer 混为一谈；两者是不同层次的渲染路径。
