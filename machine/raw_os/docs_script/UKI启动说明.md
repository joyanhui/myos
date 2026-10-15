# UKI 启动方式

## 产物

- `nixos.raw`：包含内部 `nixos-esp` 和 `nixos-root` 分区的 GPT raw 镜像。
- `rawOsBootEfi`：镜像内部的 standalone GRUB，路径为 `EFI/BOOT/BOOTX64.EFI`。
- `rawOsExternalBootEfi`：外部固定 standalone GRUB，负责从 NTFS 加载 raw 镜像。
- `nixos-current.efi`：当前系统的 UKI。
- `nixos-generation-<generation>.efi`：按 generation 保存的 UKI，最多 10 个。

## 启动链路

### 直接启动 raw 镜像

```text
UEFI
→ EFI/BOOT/BOOTX64.EFI
→ EFI/NixOS/raw-os/grub.cfg
→ 当前或指定 generation UKI
→ NixOS
```

内部 GRUB 菜单还会搜索并 chainload：

```text
/EFI/Microsoft/Boot/bootmgfw.efi
```

### 从 NTFS 启动 raw 镜像

```text
外部固定 EFI
→ NTFS:/OS-img/nixos.raw
→ raw 镜像分区 1 的 EFI/NixOS/raw-os/grub.cfg
→ 当前或指定 generation UKI
→ NixOS
```

外部固定 EFI 不依赖外部 ESP 上的菜单文件或 generation UKI。

## 构建

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

外部固定 EFI 使用 `creat-rawOsExternalBootEfi.sh` 单独构建。

## 内部 EFI 更新

`nixos-rebuild switch` 通过 external bootloader install hook 更新内部 ESP：

```text
EFI/BOOT/BOOTX64.EFI
EFI/NixOS/raw-os/grub.cfg
EFI/NixOS/raw-os/nixos-current.efi
EFI/NixOS/raw-os/nixos-generation-*.efi
```

当前 generation 必须保留，其余按 generation 编号从新到旧选择，最多保留 10 个 generation UKI。`nixos-current.efi` 独立保留，不计入数量限制。未被选中的旧 generation 文件会在新文件安装成功后删除。

## 外部 EFI 部署

首次部署时，将 `rawOsExternalBootEfi` 写入 UEFI 启动项实际指向的外部 EFI 路径，例如：

```text
EFI/Boot/nixos-img.efi
```

NTFS 分区放置：

```text
OS-img/nixos.raw
```

首次部署或外部固定 EFI 发生变化时，在仓库根目录执行：

```bash
REPO_DIR="$PWD" \
  machine/raw_os/docs_script/creat-rawOsExternalBootEfi.sh \
  -o /tmp/nixos-img.efi
```

将生成的 EFI 文件手动复制到 UEFI 启动项实际指向的外部 EFI 路径，例如：

```text
EFI/Boot/nixos-img.efi
```

普通系统更新时，替换 NTFS 中的 `OS-img/nixos.raw` 即可，外部固定 EFI 不需要更新。

## initrd 服务

`nixos-img-loop-for-root.service` 在外部启动时：

- 扫描宿主块设备；
- 挂载包含 `OS-img/nixos.raw` 的 NTFS 分区；
- 创建 raw 镜像 loop 设备；
- 按分区标签建立 `nixos-esp` 和 `nixos-root` 设备；
- 由系统配置挂载镜像内部根分区。

直接把 `nixos.raw` 作为磁盘启动时，内部根分区已存在，服务会跳过 loop 流程。

## 文件位置

```text
raw 镜像内部：
EFI/BOOT/BOOTX64.EFI
EFI/NixOS/raw-os/grub.cfg
EFI/NixOS/raw-os/nixos-current.efi
EFI/NixOS/raw-os/nixos-generation-*.efi

宿主 NTFS：
OS-img/nixos.raw
```
