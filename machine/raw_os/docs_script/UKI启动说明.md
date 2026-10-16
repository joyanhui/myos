# Raw OS 引导架构与 UKI 说明

本文档是 Raw OS 的引导架构参考，不重复维护构建、部署和运行时更新命令。实际操作统一使用 [Raw OS 主文档的构建与部署章节](../README.md#raw-os-build-and-deploy)。

## 产物

- `nixos.raw`：包含内部 `nixos-esp` 和 `nixos-root` 分区的 GPT raw 镜像。
- `rawOsBootEfi`：镜像内部的 standalone GRUB，安装路径为 `EFI/BOOT/BOOTX64.EFI`。
- `rawOsExternalBootEfi`：宿主 ESP 上的外部固定 standalone GRUB，负责从 NTFS 定位并加载 raw 镜像。
- `nixos-current.efi`：当前系统的 UKI。
- `nixos-generation-<generation>.efi`：按 NixOS generation 保存的 UKI，内部运行时最多保留 8 个。

`system.build.uki` 是基础镜像构建时用于生成初始 `nixos-current.efi` 和 `nixos-generation-1.efi` 的内部构建产物。它不是需要单独部署的外部固定 EFI，也不是日常更新命令的目标。

## 配置职责

- `raw_os_core_img_creat`：生成硬件无关的基础 raw 镜像，并把初始内部引导文件写入镜像 ESP。
- `raw_os_work_amd`：运行中的 AMD raw OS 配置，通过 `nixos-rebuild switch` 更新系统和内部 ESP。
- `raw_os_work_intel`：运行中的 Intel raw OS 配置，通过 `nixos-rebuild switch` 更新系统和内部 ESP。

初始基础镜像和运行中的工作环境是两个阶段。将新的基础镜像写入 NTFS 会替换镜像中的系统内容，不等同于更新当前 AMD 或 Intel 工作环境；运行中的系统更新应使用主文档中的对应 `raw_os_work_*` 配置。

## 启动链路

### 直接启动 raw 镜像

```text
UEFI
→ raw 内部 EFI/BOOT/BOOTX64.EFI
→ raw 内部 EFI/NixOS/raw-os/grub.cfg
→ 当前或指定 generation UKI
→ NixOS
```

`rawOsBootEfi` 是内嵌了最小配置的 standalone GRUB。它先从同一个 ESP 读取动态 `grub.cfg`，动态菜单再 chainload 当前 UKI、历史 generation UKI 或 Windows Boot Manager：

```text
/EFI/Microsoft/Boot/bootmgfw.efi
```

### 从 NTFS 启动 raw 镜像

```text
UEFI 启动项
→ 宿主 ESP 上的 rawOsExternalBootEfi
→ 搜索 NTFS:/OS-img/nixos.raw
→ loopback raw 镜像
→ 读取 raw 内部 EFI/NixOS/raw-os/grub.cfg
→ 当前或指定 generation UKI
→ NixOS
```

外部固定 EFI 只负责定位 raw 镜像和读取 raw 内部菜单，不保存以下内容：

```text
nixos-current.efi
grub.cfg
nixos-generation-*.efi
```

外部 EFI 会尝试定位宿主 ESP 上的 Windows Boot Manager。即使外部 EFI 没有找到，raw 内部动态菜单仍会再次搜索该文件。

## 内部 ESP 的更新方式

`raw_os_work_amd` 或 `raw_os_work_intel` 的 `nixos-rebuild switch` 会调用 `raw-os-runtime.nix` 提供的 external bootloader install hook。该 hook 根据系统 generation 和 `boot.json` 生成 UKI，并原子更新 raw 内部 ESP：

```text
EFI/BOOT/BOOTX64.EFI
EFI/NixOS/raw-os/grub.cfg
EFI/NixOS/raw-os/nixos-current.efi
EFI/NixOS/raw-os/nixos-generation-<generation>.efi
```

更新规则如下：

- 当前 generation 必须保留；
- `nixos-current.efi` 独立保留，不计入 generation 数量限制；
- generation UKI 按编号从新到旧最多保留 8 个；
- 新 UKI、菜单和内部 loader 安装成功后，才删除未选中的旧 generation 文件；
- `boot.loader.efi.canTouchEfiVariables = false`，不会修改 UEFI NVRAM 启动变量。

## 外部固定 EFI 的生命周期

外部固定 EFI 的部署命令见主文档的[初次构建外部固定 EFI](../README.md#raw-os-external-efi-build)。它只需要在以下情况重新构建并手动替换宿主 ESP 上的文件：

- 修改外部 GRUB 的搜索路径或启动逻辑；
- 修改 raw 内部菜单路径；
- 修改外部 EFI 使用的 GRUB 模块；
- 更新 nixpkgs 后需要重新验证外部 EFI；
- 外部 EFI 文件损坏。

以下操作不需要更新外部固定 EFI：

- 运行中的 raw OS 执行 `nixos-rebuild switch`；
- raw 内部 generation UKI 更新；
- 替换 NTFS 中的 `OS-img/nixos.raw`；
- 直接将同一个 raw 镜像写入另一块目标磁盘。

## initrd 服务

`nixos-img-loop-for-root.service` 处理从 NTFS 启动时的根文件系统映射：

- 扫描宿主块设备；
- 挂载包含 `OS-img/nixos.raw` 的 NTFS 分区；
- 创建 raw 镜像 loop 设备；
- 按分区标签建立 `nixos-esp` 和 `nixos-root` 设备链接；
- 由系统配置挂载镜像内部的 root 分区。

直接把 `nixos.raw` 作为磁盘启动时，`nixos-root` 已经是当前磁盘上的分区，服务会识别并跳过宿主 NTFS 搜索和 loop 创建流程。

## 文件位置

raw 镜像内部 ESP：

```text
EFI/BOOT/BOOTX64.EFI
EFI/NixOS/raw-os/grub.cfg
EFI/NixOS/raw-os/nixos-current.efi
EFI/NixOS/raw-os/nixos-generation-<generation>.efi
```

宿主 ESP 和 NTFS：

```text
ESP/EFI/NixOS/nixos-img.efi
NTFS/OS-img/nixos.raw
```

测试和验收流程见：[Raw OS 测试和验证方法](测试和验证方法.md)。
