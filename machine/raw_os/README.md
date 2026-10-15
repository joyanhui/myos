# Raw OS

Raw OS 使用 NixOS 构建 GPT raw 镜像。镜像可以直接写入磁盘启动，也可以放在 NTFS 分区中，由外部固定 EFI 启动。

## 构建产物

- `nixos.raw`：包含内部 ESP 和 Btrfs 根分区的 raw 镜像。
- `rawOsBootEfi`：镜像内部的 GRUB fallback loader，安装路径固定为 `EFI/BOOT/BOOTX64.EFI`。
- `rawOsExternalBootEfi`：外部固定 GRUB loader。它从 NTFS 查找 `/OS-img/nixos.raw`，不保存 generation UKI 和菜单文件。

raw 镜像和内部 EFI 应使用同一批配置构建：

```bash
mapfile -t outputs < <(
  nix build --no-link --print-out-paths \
    .#nixosConfigurations.raw_os_core_img_creat.config.system.build.image \
    .#nixosConfigurations.raw_os_core_img_creat.config.system.build.rawOsBootEfi
)
image_dir=${outputs[0]}
internal_efi=${outputs[1]}
```

外部固定 EFI 由 `creat-rawOsExternalBootEfi.sh` 单独构建。

## 启动职责

内部 EFI 位于 raw 镜像内部，负责加载内部菜单：

```text
EFI/BOOT/BOOTX64.EFI
→ EFI/NixOS/raw-os/grub.cfg
→ 当前或指定 generation UKI
```

内部 ESP 保存：

```text
EFI/BOOT/BOOTX64.EFI
EFI/NixOS/raw-os/grub.cfg
EFI/NixOS/raw-os/nixos-current.efi
EFI/NixOS/raw-os/nixos-generation-*.efi
```

`nixos-rebuild switch` 的 bootloader install hook 读取系统 generation，生成最多 10 个 generation UKI 和 `grub.cfg`，并写入 raw 镜像内部 ESP。当前 generation 必须保留，`nixos-current.efi` 不计入 10 个 generation 限额。内部菜单也包含 Windows Boot Manager：

```text
/EFI/Microsoft/Boot/bootmgfw.efi
```

外部 EFI 只保存一个固定 loader，负责定位 raw 和进入内部菜单：

```text
搜索宿主 ESP 上的 Windows EFI
→ 搜索 NTFS:/OS-img/nixos.raw
→ loopback raw
→ 读取 raw 内部 EFI/NixOS/raw-os/grub.cfg
→ 由内部菜单选择 NixOS 或 Windows
```

外部 EFI 不生成或保存 generation 列表、`grub.cfg`、`nixos-current.efi` 或 generation UKI。Windows 搜索失败时，内部菜单仍会再次搜索 Windows EFI。普通系统更新只需替换 NTFS 中的 `OS-img/nixos.raw`，不需要更新外部 EFI。

首次部署或外部固定 EFI 发生变化时，使用脚本单独构建外部 EFI：

```bash
REPO_DIR="$PWD" \
  machine/raw_os/docs_script/creat-rawOsExternalBootEfi.sh \
  -o /tmp/nixos-img.efi
```

然后将生成的 EFI 文件手动复制到 UEFI 启动项实际指向的 EFI 路径。普通系统更新只需替换 NTFS 中的 `OS-img/nixos.raw`，不需要重新生成或更新外部 EFI。

## 直接写盘

将 raw 镜像写入目标磁盘后，UEFI 从镜像内部的 `EFI/BOOT/BOOTX64.EFI` 启动：

```bash
sudo dd if=nixos.raw of=/dev/<target-disk> bs=16M status=progress conv=fsync
```

目标磁盘上的原有数据会被覆盖。

## 镜像扩容

将镜像、GPT 第二分区和 Btrfs 根分区扩展到指定大小：

```bash
machine/raw_os/docs_script/resize-raw-image.sh \
  nixos.raw 30G --resize-btrfs
```

## QEMU

QEMU 使用只读 `OVMF.fd` 和独立复制的 `OVMF_VARS.fd`。启动 raw 镜像时，`nixos-img-loop-for-root.service` 检测到根分区已经存在，会跳过宿主 NTFS 搜索。
