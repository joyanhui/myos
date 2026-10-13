# UKI 启动方式

## 启动文件

外部启动使用 NixOS 构建的 Unified Kernel Image（UKI）：

- EFI 文件来源：`config.system.build.uki`
- 默认文件名：`nixos-img.efi`
- 文件内容：kernel、initrd、内核参数和 systemd EFI stub
- 镜像文件：GPT raw，内部包含 ESP 和标记为 `nixos-root` 的 Btrfs 分区
- 宿主文件：NTFS 分区上的 `OS-img/nixos.raw`

EFI 文件与 `nixos.raw` 使用同一次构建生成。

## 启动链路

1. UEFI 从 ESP 加载启动项指向的 EFI 文件。
2. UKI 提供 kernel 和 initrd。
3. initrd 启动 `nixos-img-loop-for-root.service`。
4. 服务扫描宿主块设备并挂载 NTFS 分区。
5. 服务查找 `OS-img/nixos.raw`，创建 loop 设备并扫描其 GPT 分区。
6. 服务按分区标签建立 `ESP` 和 `nixos-root` 设备链接。
7. NixOS 按 `root=fstab` 挂载 Btrfs 根分区并继续启动。

## 生成 EFI 文件

构建镜像和 UKI：

```sh
image_dir=$(nix build --no-link --print-out-paths \
  .#nixosConfigurations.raw_os_core_img_creat.config.system.build.image)
uki_dir=$(nix build --no-link --print-out-paths \
  .#nixosConfigurations.raw_os_core_img_creat.config.system.build.uki)
```

在临时目录生成外部 EFI 文件：

```sh
mkdir -p /tmp/nixos-img
machine/raw_os/docs_script/create-nixos-img-uki-efi.sh \
  "$uki_dir" \
  -o /tmp/nixos-img/nixos-img.efi
```

脚本也接受直接的 `.efi` 文件：

```sh
machine/raw_os/docs_script/create-nixos-img-uki-efi.sh \
  "$uki_dir/nixos-img.efi" \
  -o /tmp/nixos-img/nixos-img.efi
```

## 部署到 ESP

EFI 文件名和目录由 UEFI 启动项引用。例如：

```text
ESP/EFI/NixOS/nixos-img.efi
```

DiskGenius 启动项配置：

- 分区：FAT32 ESP 分区
- EFI 文件：`\EFI\NixOS\nixos-img.efi`
- 启动项名称：`NixOS raw UKI`

宿主 NTFS 分区中的镜像路径：

```text
OS-img/nixos.raw
```

## 直接启动 raw 磁盘

将 `nixos.raw` 写入 U 盘、移动硬盘或内部磁盘后，使用镜像内部 ESP 的 systemd-boot 启动：

```text
nixos.raw
├── ESP
│   └── EFI/Linux/nixos-img.efi
└── nixos-root
```

## 更新要求

kernel、initrd 或内核参数变化后，重新构建并部署 EFI 文件和 raw 镜像：

```sh
uki_dir=$(nix build --no-link --print-out-paths \
  .#nixosConfigurations.raw_os_core_img_creat.config.system.build.uki)
machine/raw_os/docs_script/create-nixos-img-uki-efi.sh \
  "$uki_dir" \
  -o /tmp/nixos-img/nixos-img.efi
```

## QEMU 闭环测试

测试宿主盘结构：

```text
宿主 qcow2
├── ESP 分区：放置 nixos-img.efi
└── NTFS 分区
    └── OS-img/nixos.raw
```

QEMU 使用宿主 qcow2 和独立的 `OVMF_VARS.fd` 启动。验收日志：

```text
IMGLOOP:start
IMGLOOP:found nixos.raw
IMGLOOP:losetup nixos.raw
IMGLOOP:done
```

## 文件用途

- `nixos.raw`：NixOS 镜像
- `nixos-img.efi`：UEFI 启动文件
- `OVMF.fd`：QEMU 只读固件
- `OVMF_VARS.fd`：QEMU 可写 NVRAM 模板
