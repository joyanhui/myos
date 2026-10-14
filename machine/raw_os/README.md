# Raw OS

Raw OS 使用 NixOS 构建 GPT raw 镜像。并支持同一个虚拟磁盘文件可虚拟机启动可以物理机启动可烧录到磁盘启动，使用linux7.x内核级ntfs驱动挂载 使用uki定制efi实现。

> 最终产物 为 一个 nixos.raw 系统镜像文件 和一个内部外部通用的 EFI启动文件

Linux 的 UKI（Unified Kernel Image）是一种将内核、initramfs、UEFI 引导 stub、微码等资源打包成单一 EFI 可执行文件的格式，可被 UEFI 固件直接引导，并便于 Secure Boot 签名

## 构建

克隆仓库

```bash
mkdir ~/myws && cd ~/myws # 最好就使用这个路径,否则需要修改global_setting_vars.nix
git clone https://github.com/joyanhui/myos.git
```

构建 raw 镜像：

```bash
nix build --no-link --print-out-paths \
  .#nixosConfigurations.raw_os_core_img_creat.config.system.build.image
```

构建 UKI和efi：

```bash
uki_dir=$(nix build --no-link --print-out-paths \
  .#nixosConfigurations.raw_os_core_img_creat.config.system.build.uki)
machine/raw_os/docs_script/create-nixos-img-uki-efi.sh \
  "$uki_dir" -o /tmp/nixos-img.efi
```

`nixos.raw` 和 `nixos-img.efi` 需使用同一次构建生成，部分会导致efi无法启动对应的系统。

## 镜像与启动链路

`nixos.raw` 是 GPT raw 镜像，内部含两个分区：

- `nixos-esp`：FAT32 ESP，存放内部启动用的 `EFI/BOOT/BOOTX64.EFI`
- `nixos-root`：Btrfs 根分区

UEFI 加载 UKI 后，initrd 的 `nixos-img-loop-for-root.service` 扫描宿主分区，在 NTFS 上定位 `OS-img/nixos.raw`，创建 loop 设备并按分区标签建立设备链接，然后挂载 `nixos-root` 完成启动。直接以 `nixos.raw` 为磁盘启动时，服务检测到根分区已存在会跳过 loop 流程。

## 从宿主 NTFS 文件启动

宿主任意 NTFS 分区的根目录创建一个OS-img目录里面 `nixos.raw` 文件，例如：`D:/OS-img/nixos.raw`。

使用 DiskGenius 将 UKI 文件复制到 FAT32 EFI 分区的自定义路径，例如：`EFI/NixOS/nixos-img.efi`

使用 DiskGenius 注册 UEFI 启动项，指向该自定义 EFI 文件。外部 EFI 不固定使用 `EFI/BOOT/BOOTX64.EFI` 避免和用户物理机的现有efi冲突。

运行系统更新后，在外部 EFI 启动的 NixOS 中执行：`sudo updateExternalEfi`

命令读取当前 UEFI 启动项中的 GPT 分区 UUID 和 EFI 文件路径，定位 FAT32 EFI 分区，并将当前系统 UKI 更新到该自定义路径。从 raw 内部启动时，命令会识别并跳过。

## 直接启动镜像

将 `nixos.raw` 写入 U 盘、移动硬盘或内部磁盘后，UEFI 通过镜像内部 nixos-esp分区的`EFI/BOOT/BOOTX64.EFI` 来启动。

该文件是直接启动的 UKI，不是 systemd-boot（目前已经在研究完全不再依赖systemd-boot）。

## QEMU

QEMU efi启动需要两个pflash文件 OVMF.fd OVMF_VARS.fd(模拟uefi) 可以从qemu安装路径里面找到 或者本仓库的kvm-config\firmware目录下。

可以在win/linux/mac下使用不同的后端启动 raw 镜像, 在win下使用whpx(hyperV) Linux下使用kvm macos下使用HVF,下面是win下启动的完整命令

```powershell
'C:\Program Files\qemu\qemu-system-x86_64.exe' `
  -machine q35 -accel whpx `
  -cpu max  -smp 4 -m 4096 `
  -drive if=pflash,format=raw,readonly=on,file=N:\OS-img\OVMF.fd `
  -drive if=pflash,format=raw,file=N:\OS-img\OVMF_VARS.fd `
  -drive file=N:\OS-img\nixos.raw,format=raw,if=virtio `
  -netdev user,id=n0 `
  -device virtio-net-pci,netdev=n0 `
  -vga virtio `
  -display gtk
```

## 镜像扩容

扩展镜像文件、GPT 第二分区和 Btrfs 文件系统：

```bash
machine/raw_os/docs_script/resize-raw-image.sh nixos.raw 20G --resize-btrfs
```

有一个同等能力的ps1 可以在Windows下完成扩展，但是需要在linux环境验证。

## VHD 转换

生成 fixed VHD：

```bash
  machine/raw_os/docs_script/additional-foot-to-raw-and-renameVHD.sh  nixos.raw
```

或者直接使用qemu-img转换也是一样的
