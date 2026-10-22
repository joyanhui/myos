# reims-macos-wsl2

在 WSL2（嵌套 KVM）里用 Reims vGPU + OpenCore 跑 macOS Ventura，Metal 走 Mesa Dozen（Vulkan→D3D12）硬件渲染到本机 AMD GPU，通过 VNC/noVNC 操作。

参考：

- <https://github.com/fengxinrui2012/reims-macos-wsl2>
- <https://github.com/steelbrain/reims-vgpu>
- <https://github.com/kholia/OSX-KVM>

## 路线

- Reims vGPU 定制 QEMU（`vendor/qemu` 子模块）+ `reims-vgpu-pci` 设备
- host 侧 Vulkan 用 Mesa `dzn`（Dozen，Vulkan→D3D12，走 WSL 的 `/usr/lib/wsl/lib` 到 Windows GPU 驱动），需要 Windows 侧 AMD 驱动版本够新（dxgkrnl 通路）
- macOS 端由 guest 驱动在线握手（ONLINE_ACK）后提供 Metal 硬件加速
- 显示走 QEMU VNC + websockify/noVNC（浏览器 `http://localhost:6080/vnc.html`）；Reims 自带的 winit host 窗口在 WSLg 下会段错误，不用
- `--sw`（lavapipe 软件）可作为无硬件时的降级试验，但 GPU 握手可能卡住，正式用 `--hw`

## 文件

- `create.sh` 取 Ventura 恢复映像、OpenCore/OVMF，把 DMG 转成整盘 raw，建 128G 系统盘
- `build.sh` clone reims-vgpu、编译定制 QEMU（vulkan 后端）与 GOP ROM，产物放到 `$MACOS_VM_DIR/reims/`
- `start.sh` 启动虚拟机（`--hw` dzn / `--sw` lavapipe）

## 依赖

`curl`、`openssl`、`python3`、`qemu-img`、`git`、`nix`；构建需要 `cargo`/`nixpkgs` 里的 meson/ninja 等（build.sh 自动进 nix shell）。首次 build.sh 会 clone reims-vgpu 并编译（约 10-20 分钟），之后增量很快。

## 用法

```
./create.sh          # 下载恢复映像与 OpenCore/OVMF，生成磁盘
./build.sh           # 编译 reims QEMU + GOP ROM
./start.sh --hw      # dzn 硬件加速
./start.sh --sw      # lavapipe 软件降级
```

数据目录默认 `/home/nixos/vdisks/macos`，用 `MACOS_VM_DIR` 覆盖。

VNC 在 `127.0.0.1:5900`；浏览器操作建议：

```
websockify --web=/usr/share/novnc 6080 localhost:5900
# 浏览器打开 http://localhost:6080/vnc.html
```

## 安装 Ventura

1. `start.sh --hw` 起来后在 OpenCore 选单选 `macOS Base System` 进入恢复环境
2. 打开 `磁盘工具`，侧栏选中 `QEMU HARDDISK`，抹掉为 APFS（名称随意），完成后关掉
3. 点 `重新安装 macOS Ventura` -> 继续 -> 同意协议 -> 选中已抹磁盘 -> 安装
4. 安装过程从 Apple CDN 下载约 13G，会重启多次，OpenCore 里选 `macOS Installer` / `Macintosh HD` 继续
5. 装完是设置助手；安装器会取该机型可用的最新 Ventura，即 13.7.8

## 环境变量

- `MACOS_VM_DIR` 数据目录，默认 `/home/nixos/vdisks/macos`
- `MACOS_RAM` 内存，默认 `8G`
- `MACOS_CPUS` 核心数，默认 `4`
- `MACOS_MAC` 网卡 MAC，默认 `52:54:00:c9:18:27`
- `MACOS_SSH_PORT` 主机转发到 guest 22 的端口，默认 `2222`
- `MACOS_VNC_DISPLAY` VNC display 号，默认 `0`（端口 5900）
- `MACOS_DISK_SIZE` 系统盘大小，默认 `128G`
- `MACOS_BOARD_ID` 恢复映像 board id，默认 `Mac-4B682C642B45593E`
- `MACOS_OSXKVM_RAW` OpenCore/OVMF 下载源前缀
- `REIMS_ICD` 覆盖 ICD 选择（`dzn`/`lvp`/`auto`）
- `REIMS_SRC` reims-vgpu 源码目录，默认 `/tmp/reims-vgpu`

## 控制

QEMU 的 monitor socket 在 `$MACOS_VM_DIR/monitor.sock`：

```
printf 'screendump /tmp/shot.ppm\n' | socat - UNIX-CONNECT:/home/nixos/vdisks/macos/monitor.sock
printf 'sendkey ret\n' | socat - UNIX-CONNECT:/home/nixos/vdisks/macos/monitor.sock
printf 'quit\n' | socat - UNIX-CONNECT:/home/nixos/vdisks/macos/monitor.sock
```

## 网络

guest 走 QEMU 用户态网络：`en0` 拿到 `10.0.2.15`，主机 2222 端口转发到 guest 22。

## 备注

- `BaseSystem.dmg` 必须转成整盘 raw 镜像（含保护 MBR、GPT、HFS+ 分区）。只把 HFS+ 分区内容当作整盘使用，安装器会卡在 `Still waiting for root device`；`create.sh` 内置的就是 dmg2img 那个转换的等价实现
- CPU 用 `Skylake-Client,vendor=GenuineIntel` 伪装 Intel，AMD 机器靠这层伪装启动；实测 R7-7735HS 能进恢复环境并安装
- 分辨率 1920x1080（reims-vgpu-efi GOP ROM 缺省）
- dzn 硬件加速要求 Windows 侧 AMD 驱动能过 dxgkrnl 枚举；驱动太旧（如 2023 OEM 版）会报 `ID3D12DeviceFactory::CreateDevice failed`，装 WHQL 24.12.1 或更新版本可解决