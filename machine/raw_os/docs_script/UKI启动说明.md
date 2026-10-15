# UKI 启动方式

## 文件和路径

- `nixos.raw`：GPT raw 镜像，包含内部 `nixos-esp` 和 `nixos-root` 分区。
- `nixos-img.efi`：由 `config.system.build.uki` 生成的初始 UKI，用于注册外部自定义 EFI 启动项。
- `EFI/BOOT/BOOTX64.EFI`：raw 镜像内部的 GRUB loader。
- `EFI/NixOS/raw-os/`：GRUB 菜单、当前 UKI 和按 generation 保存的 UKI。
- 内部启动路径固定为：`EFI/BOOT/BOOTX64.EFI`。
- 外部启动路径由当前 UEFI 启动项决定，例如：`EFI/NixOS/nixos-img.efi`。
- 宿主 NTFS 文件固定为：`OS-img/nixos.raw`。

image 和初始 UKI 必须来自同一条构建命令。首次部署外部 ESP 时可先放置初始 UKI；第一次从该启动项进入 NixOS 后执行 `updateExternalEfi`，此后该自定义路径保存 GRUB loader。

## 启动链路

内部直接启动：

1. UEFI 从 `EFI/BOOT/BOOTX64.EFI` 加载内嵌配置的 GRUB loader。
2. GRUB 加载内部 ESP 上选中的 generation UKI。
3. UKI 启动 kernel 和 initrd。
4. raw 镜像内部的 `nixos-esp` 和 `nixos-root` 被挂载。
5. NixOS 继续启动。

外部 EFI 启动：

1. UEFI 从启动项指定的外部自定义 EFI 路径加载 UKI。
2. initrd 启动 `nixos-img-loop-for-root.service`。
3. 服务扫描宿主块设备并挂载 NTFS 分区。
4. 服务查找 `OS-img/nixos.raw`，创建 loop 设备并扫描其 GPT 分区。
5. 服务按分区标签建立 `nixos-esp` 和 `nixos-root` 设备链接。
6. NixOS 挂载镜像内部的 Btrfs 根分区并继续启动。

## 构建和生成 EFI

image 和 UKI 必须在同一批构建中生成：

```bash
mapfile -t outputs < <(
  nix build --no-link --print-out-paths \
    .#nixosConfigurations.raw_os_core_img_creat.config.system.build.image \
    .#nixosConfigurations.raw_os_core_img_creat.config.system.build.uki
)
image_dir=${outputs[0]}
uki_dir=${outputs[1]}

mkdir -p /tmp/nixos-img
cp "$image_dir/nixos.raw" /tmp/nixos-img/nixos.raw
machine/raw_os/docs_script/create-nixos-img-uki-efi.sh \
  "$uki_dir" -o /tmp/nixos-img/nixos-img.efi
```

## 外部部署

在 FAT32 外部 ESP 放置初始 UKI，例如：

```text
EFI/NixOS/nixos-img.efi
```

在同一 ESP 的其他自定义路径也可以使用，但必须让 UEFI 启动项指向实际路径。外部 EFI 不使用内部 fallback 路径作为其启动项目标。在宿主 NTFS 分区创建：

```text
OS-img/nixos.raw
```

首次从该启动项进入 NixOS 后执行：

```bash
sudo updateExternalEfi
```

命令读取当前 `BootCurrent` 对应的 GPT 分区 UUID 和 EFI 路径，将内部 GRUB loader、菜单配置和所有 generation UKI 同步到当前外部 ESP。外部 loader 写入当前 UEFI 启动项指定的路径，不会写入或改用 `EFI/BOOT/BOOTX64.EFI`。若系统从 raw 内部 fallback 启动，命令输出跳过信息，不更新外部 EFI。

## 内部更新

`nixos-rebuild switch` 通过 external bootloader install hook 更新：

```text
/boot/EFI/BOOT/BOOTX64.EFI
/boot/EFI/NixOS/raw-os/grub.cfg
/boot/EFI/NixOS/raw-os/nixos-generation-<generation>.efi
```

每个 generation 单独生成 UKI，旧 generation 文件会被清理；不设置 generation 数量上限。内部不会创建 `EFI/Linux/nixos-img.efi`，也不会把外部 EFI 路径改成 `EFI/BOOT/BOOTX64.EFI`。

## QEMU

QEMU 使用只读固件 `OVMF.fd` 和每次测试独立复制的可写 NVRAM `OVMF_VARS.fd`。完整闭环请按 `测试和验证方法.md` 执行。

关键启动日志：

```text
IMGLOOP:start
IMGLOOP:found nixos.raw
IMGLOOP:losetup nixos.raw
IMGLOOP:done
```

## 文件用途

- `nixos.raw`：内部可直接启动、也可被外部 UKI 加载的 raw 镜像。
- `nixos-img.efi`：首次部署时外部自定义路径使用的 UKI；执行 `updateExternalEfi` 后该路径保存 GRUB loader。
- `EFI/BOOT/BOOTX64.EFI`：raw 镜像内部的 GRUB fallback loader 文件。
- `OVMF.fd`：QEMU 只读 UEFI 固件。
- `OVMF_VARS.fd`：QEMU 可写 UEFI 变量模板。
