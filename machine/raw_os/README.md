# Raw OS

Raw OS 使用 NixOS 构建 GPT raw 镜像。并支持同一个虚拟磁盘文件可虚拟机启动可以物理机启动可烧录到磁盘启动，使用linux7.x内核级ntfs驱动挂载 使用uki定制efi实现。

> 产物包括 `nixos.raw`、内部 GRUB loader，以及首次注册外部启动项使用的 UKI。外部更新后，自定义 EFI 路径保存 GRUB loader。

Linux 的 UKI（Unified Kernel Image）是一种将内核、initramfs、UEFI 引导 stub、微码等资源打包成单一 EFI 可执行文件的格式，可被 UEFI 固件直接引导，并便于 Secure Boot 签名

## 构建

克隆仓库

```bash
mkdir ~/myws && cd ~/myws # 最好就使用这个路径,否则需要修改global_setting_vars.nix
git clone https://github.com/joyanhui/myos.git
```

image 和 UKI 必须在同一条构建命令中生成：

```bash
mapfile -t outputs < <(
  nix build --no-link --print-out-paths \
    .#nixosConfigurations.raw_os_core_img_creat.config.system.build.image \
    .#nixosConfigurations.raw_os_core_img_creat.config.system.build.uki
)
image_dir=${outputs[0]}
uki_dir=${outputs[1]}
cp --reflink=auto "$image_dir/nixos.raw" /tmp/nixos.raw
machine/raw_os/docs_script/create-nixos-img-uki-efi.sh \
  "$uki_dir" -o /tmp/nixos-img.efi
```

`nixos-img.efi` 是外部启动项的初始 UKI。raw 镜像内部的菜单 loader 和各 generation UKI 由同一批 system 构建生成。

## 镜像与启动链路

`nixos.raw` 是 GPT raw 镜像，内部含两个分区：

- `nixos-esp`：FAT32 ESP，存放内部 `EFI/BOOT/BOOTX64.EFI`、菜单配置和 generation UKI
- `nixos-root`：Btrfs 根分区

`EFI/BOOT/BOOTX64.EFI` 是内嵌配置的 GRUB loader，它从同一 ESP 加载动态菜单。菜单包含所有发现的 NixOS generation，并搜索 Windows 引导文件。UKI 的 initrd 仍由 `nixos-img-loop-for-root.service` 扫描宿主分区，在 NTFS 上定位 `OS-img/nixos.raw`，创建 loop 设备并按分区标签建立设备链接，然后挂载 `nixos-root` 完成启动。直接以 `nixos.raw` 为磁盘启动时，服务检测到根分区已存在会跳过 loop 流程。

## 从宿主 NTFS 文件启动

宿主任意 NTFS 分区的根目录创建一个OS-img目录里面 `nixos.raw` 文件，例如：`D:/OS-img/nixos.raw`。

使用 DiskGenius 将初始 UKI 文件复制到 FAT32 EFI 分区的自定义路径，例如：`EFI/NixOS/nixos-img.efi`

使用 DiskGenius 注册 UEFI 启动项，指向该自定义 EFI 文件。外部 EFI 不固定使用 `EFI/BOOT/BOOTX64.EFI` 避免和用户物理机的现有efi冲突。

运行系统更新后，在外部 EFI 启动的 NixOS 中执行：`sudo updateExternalEfi`

命令读取当前 UEFI 启动项中的 GPT 分区 UUID 和 EFI 文件路径，定位 FAT32 EFI 分区，并将内部 GRUB loader、菜单配置和所有 generation UKI 原子同步到该自定义路径及其 `EFI/NixOS/raw-os` 数据目录。外部路径始终使用当前 UEFI 启动项的实际路径，不会改成 `EFI/BOOT/BOOTX64.EFI`，也不会修改 Windows 文件。从 raw 内部 fallback 启动时，命令会识别并跳过。

## 直接启动镜像

将 `nixos.raw` 写入 U 盘、移动硬盘或内部磁盘后，UEFI 通过镜像内部 nixos-esp 分区的 `EFI/BOOT/BOOTX64.EFI` 启动 GRUB 菜单。选择 NixOS generation 后，GRUB chainload 对应的 UKI；也可以选择搜索到的 Windows Boot Manager。

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
