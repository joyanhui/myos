# Raw OS

Raw OS 使用 NixOS 构建 GPT raw 镜像。镜像包含：

- ESP 分区
- `nixos-root` Btrfs 分区
- systemd-boot 和 UKI 启动文件

## 构建

构建 raw 镜像：

```bash
nix build --no-link --print-out-paths \
  .#nixosConfigurations.raw_os_core_img_creat.config.system.build.image \
  --option substituters https://cache.nixos.org
```

构建 UKI：

```bash
nix build --no-link --print-out-paths \
  .#nixosConfigurations.raw_os_core_img_creat.config.system.build.uki \
  --option substituters https://cache.nixos.org
```

生成外部 EFI 文件：

```bash
uki_dir=$(nix eval --raw \
  .#nixosConfigurations.raw_os_core_img_creat.config.system.build.uki)

machine/raw_os/docs_script/create-nixos-img-uki-efi.sh \
  "$uki_dir" \
  -o /tmp/nixos-img.efi
```

`nixos.raw` 和 `nixos-img.efi` 使用同一次构建生成。

## 从宿主 NTFS 文件启动

宿主 NTFS 分区的文件布局：

```text
NTFS
└── OS-img
    └── nixos.raw
```

ESP 中放置 UKI 文件，例如：

```text
ESP
└── EFI
    └── NixOS
        └── nixos-img.efi
```

使用 DiskGenius 注册 UEFI 启动项：

- 分区：FAT32 ESP 分区
- EFI 文件：`\EFI\NixOS\nixos-img.efi`
- 启动项名称：`NixOS raw UKI`

EFI 文件名和目录可以按启动项路径设置。UEFI 加载 UKI 后，initrd 扫描 NTFS 分区并映射 `OS-img/nixos.raw`，随后挂载镜像内部的 `nixos-root`。

## 直接启动镜像

将 `nixos.raw` 写入 U 盘、移动硬盘或内部磁盘后，使用镜像内部 ESP 的 systemd-boot 启动。

## QEMU

QEMU 固件位于：

```text
kvm-config/firmware/OVMF.fd
kvm-config/firmware/OVMF_VARS.fd
```

启动 raw 镜像：

```powershell
qemu-system-x86_64.exe `
  -machine q35 `
  -accel whpx `
  -cpu max `
  -smp 4 `
  -m 4096 `
  -drive if=pflash,format=raw,readonly=on,file=V:\OS-img\OVMF.fd `
  -drive if=pflash,format=raw,file=V:\OS-img\OVMF_VARS.fd `
  -drive file=V:\OS-img\nixos.raw,format=raw,if=virtio `
  -netdev user,id=n0 `
  -device virtio-net-pci,netdev=n0 `
  -vga virtio `
  -display gtk
```

`OVMF.fd` 是只读固件，`OVMF_VARS.fd` 保存虚拟机 UEFI 变量。

## 镜像扩容

扩展镜像文件、GPT 第二分区和 Btrfs 文件系统：

```bash
machine/raw_os/docs_script/resize-raw-image.sh \
  nixos.raw 20G --resize-btrfs
```

只扩展镜像文件和 GPT 第二分区：

```bash
machine/raw_os/docs_script/resize-raw-image.sh \
  nixos.raw 20G --skip-btrfs-resize
```

## VHD 转换

生成 fixed VHD：

```bash
nix shell nixpkgs#qemu -c \
  machine/raw_os/docs_script/additional-foot-to-raw-and-renameVHD.sh \
  nixos.raw
```

该脚本生成同目录下的 `.vhd` 文件，并删除输入的 `.raw` 文件。

## 相关文件

- `raw-os-core-img-creat.nix`：raw 镜像配置
- `raw-os-runtime.nix`：镜像运行时配置和 initrd 文件映射服务
- `raw-os-work.nix`：工作环境配置
- `docs_script/create-nixos-img-uki-efi.sh`：生成外部 UKI EFI 文件
- `docs_script/resize-raw-image.sh`：扩展 raw 镜像
- `docs_script/resize-raw-image.ps1`：Windows PowerShell 扩展脚本
- `docs_script/additional-foot-to-raw-and-renameVHD.sh`：生成 fixed VHD
- `docs_script/UKI启动说明.md`：UKI 启动说明
- `docs_script/测试和验证方法.md`：QEMU 测试方法
