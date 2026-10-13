# Raw OS

Raw OS 使用 NixOS 构建 GPT raw 镜像。并支持同一个虚拟磁盘文件可虚拟机启动可以物理机启动可烧录到磁盘启动，使用linux7.x内核级ntfs驱动挂载 使用uki定制efi实现。

> 最终产物 为 一个 nixos.raw 系统镜像文件 和一个外部 EFI启动文件

## 构建

克隆仓库

```bash
mkdir ~/myws && cd ~/myws # 最好就使用这个路径,否则需要修改global_setting_vars.nix
git clone https://github.com/joyanhui/myos.git
```

构建 raw 镜像：

```bash
nix build --no-link --print-out-paths \
  .#nixosConfigurations.raw_os_core_img_creat.config.system.build.image \
  --option substituters https://cache.nixos.org
```

构建 UKI：

```bash
uki_dir=$(nix build --no-link --print-out-paths \
  .#nixosConfigurations.raw_os_core_img_creat.config.system.build.uki \
  --option substituters https://cache.nixos.org)
```

生成外部 EFI 文件：

```bash
machine/raw_os/docs_script/create-nixos-img-uki-efi.sh \
  "$uki_dir" \
  -o /tmp/nixos-img.efi
```

`nixos.raw` 和 `nixos-img.efi` 使用同一次构建生成。

## 从宿主 NTFS 文件启动

宿主任意 NTFS 分区的的根目录中放nixos.raw文件，例如：D:/OS-img/nixos.raw

使用 DiskGenius 将 UKI 文件复制到 FAT32 EFI 分区，例如：

```text
EFI/NixOS/nixos-img.efi
```

使用 DiskGenius 注册 UEFI 启动项，指向该 EFI 文件。

运行系统更新后，在 NixOS 中执行：

```bash
sudo updateExternalEfi
```

命令读取当前 UEFI 启动项中的 GPT 分区 UUID 和 EFI 文件路径，定位 FAT32 EFI 分区，并将当前系统 UKI 更新到该路径。

UEFI 加载 UKI 后，initrd 扫描 NTFS 分区并映射 `OS-img/nixos.raw`，随后挂载镜像内部的 `nixos-root`。

## 直接启动镜像

将 `nixos.raw` 写入 U 盘、移动硬盘或内部磁盘后，直接使用镜像内部 ESP 的 systemd-boot 即可启动。

## QEMU

QEMU efi启动需要两个pflash文件 OVMF.fd OVMF_VARS.fd 可以从qemu安装路径里面找到

启动 raw 镜像：

```powershell
'C:\Program Files\qemu\qemu-system-x86_64.exe' `
  -machine q35 `
  -accel whpx `
  -cpu max `
  -smp 4 `
  -m 4096 `
  -drive if=pflash,format=raw,readonly=on,file=N:\OS-img\OVMF.fd `
  -drive if=pflash,format=raw,file=N:\OS-img\OVMF_VARS.fd `
  -drive file=N:\OS-img\nixos.raw,format=raw,if=virtio `
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

## VHD 转换

生成 fixed VHD：

```bash
nix shell nixpkgs#qemu -c \
  machine/raw_os/docs_script/additional-foot-to-raw-and-renameVHD.sh \
  nixos.raw
```

或者直接使用qemu-img转换也是一样的
