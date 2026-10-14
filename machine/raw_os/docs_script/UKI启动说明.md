# UKI 启动方式

## 文件和路径

- `nixos.raw`：GPT raw 镜像，包含内部 `nixos-esp` 和 `nixos-root` 分区。
- `nixos-img.efi`：由 `config.system.build.uki` 生成的 UKI，用于外部自定义 EFI 路径。
- 内部启动路径固定为：`EFI/BOOT/BOOTX64.EFI`。
- 外部启动路径由 UEFI 启动项决定，例如：`EFI/NixOS/nixos-img.efi`。
- 宿主 NTFS 文件固定为：`OS-img/nixos.raw`。

`nixos.raw` 和 `nixos-img.efi` 必须来自同一批构建。内部 fallback 文件和外部自定义 EFI 文件是同一个 UKI 的不同路径副本。

## 启动链路

内部直接启动：

1. UEFI 从 `EFI/BOOT/BOOTX64.EFI` 加载 UKI。
2. UKI 启动 kernel 和 initrd。
3. raw 镜像内部的 `nixos-esp` 和 `nixos-root` 被挂载。
4. NixOS 继续启动。

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

在 FAT32 外部 ESP 放置 UKI，例如：

```text
EFI/NixOS/nixos-img.efi
```

在同一 ESP 的其他自定义路径也可以使用，但必须让 UEFI 启动项指向实际路径。外部 EFI 不使用内部 fallback 路径作为其启动项目标。

在宿主 NTFS 分区创建：

```text
OS-img/nixos.raw
```

运行系统更新后，只有从外部 EFI 启动时才执行：

```bash
sudo updateExternalEfi
```

命令读取当前 `BootCurrent` 对应的 GPT 分区 UUID 和 EFI 路径，将 `/boot/EFI/BOOT/BOOTX64.EFI` 更新到当前外部启动项指向的文件。若系统从 raw 内部 fallback 启动，命令输出跳过信息，不更新外部 EFI。

## 内部更新

`nixos-rebuild switch` 通过 external bootloader install hook 原子更新：

```text
/boot/EFI/BOOT/BOOTX64.EFI
```

内部不会创建 `EFI/Linux/nixos-img.efi`，也不会把外部 EFI 路径改成 `EFI/BOOT/BOOTX64.EFI`。

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
- `nixos-img.efi`：外部自定义路径使用的 UKI 文件。
- `EFI/BOOT/BOOTX64.EFI`：raw 镜像内部的 UEFI fallback UKI 文件。
- `OVMF.fd`：QEMU 只读 UEFI 固件。
- `OVMF_VARS.fd`：QEMU 可写 UEFI 变量模板。
