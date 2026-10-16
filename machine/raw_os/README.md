# Raw OS

Raw OS 使用 NixOS 构建 GPT raw 镜像。镜像可以直接写入磁盘启动，也可以放在 NTFS 分区中，由宿主 ESP 上的外部固定 EFI 启动。

本文件是 Raw OS 的构建、部署和更新主文档。其他 Raw OS 文档只说明架构或测试方法，不重复维护构建命令。

<a id="raw-os-build-and-deploy"></a>

## 构建与部署

### 配置职责

- `raw_os_core_img_creat`
  - 基础镜像构建配置。
  - 生成初始 `nixos.raw`。
  - 为 raw 内部生成 `rawOsBootEfi`、菜单文件和初始 UKI。
  - 生成与硬件平台无关的基础系统，不包含 `raw_os_work_amd` 或 `raw_os_work_intel` 的完整工作环境。
- `raw_os_work_amd`
  - 运行在 raw OS 内的 AMD 工作环境配置。
  - 通过 `raw-amd` tag 启用 AMD IOMMU、KVM 和 VFIO 设置。
  - 用 `nixos-rebuild switch` 更新运行中的系统和 raw 内部 ESP。
- `raw_os_work_intel`
  - 运行在 raw OS 内的 Intel 工作环境配置。
  - 通过 `raw-intel` tag 启用 Intel IOMMU、KVM 和 VFIO 设置。
  - 用 `nixos-rebuild switch` 更新运行中的系统和 raw 内部 ESP。

### 产物和职责

| 产物                   | 来源                                              | 部署位置                                | 用途                             | 普通系统更新是否更新       |
| ---------------------- | ------------------------------------------------- | --------------------------------------- | -------------------------------- | -------------------------- |
| `nixos.raw`            | `raw_os_core_img_creat.config.system.build.image` | 目标磁盘，或 NTFS 的 `OS-img/nixos.raw` | raw 系统镜像                     | 不直接更新；替换镜像时更新 |
| `rawOsBootEfi`         | `system.build.rawOsBootEfi`                       | raw 内部 `EFI/BOOT/BOOTX64.EFI`         | 内部 standalone GRUB loader      | 是                         |
| raw 内部菜单和 UKI     | `nixos-rebuild switch` 的 bootloader install hook | raw 内部 `EFI/NixOS/raw-os/`            | generation 菜单和 NixOS 启动载荷 | 是                         |
| `rawOsExternalBootEfi` | `system.build.rawOsExternalBootEfi`               | 宿主 ESP 的自定义 EFI 路径              | 搜索并加载 NTFS 中的 raw 镜像    | 否                         |

`system.build.uki` 是基础镜像构建过程使用的内部构建产物，不是需要单独部署或单独更新的外部 EFI。不要按照旧文档单独构建 `system.build.uki`。

<a id="raw-os-initial-build"></a>

### 初次构建

以下命令是 Raw OS 初始构建的唯一标准命令。命令需要在仓库根目录执行，并将基础镜像复制为当前目录的 `nixos.raw`：

```bash
set -euo pipefail
repo_dir="$(git rev-parse --show-toplevel)"
cd "$repo_dir"
image_dir="$(nix build --no-link --print-out-paths \
  .#nixosConfigurations.raw_os_core_img_creat.config.system.build.image)"
cp --reflink=auto "$image_dir/nixos.raw" "$repo_dir/nixos.raw"
```

构建得到的 raw 镜像内部已经包含：

```text
EFI/BOOT/BOOTX64.EFI
EFI/NixOS/raw-os/grub.cfg
EFI/NixOS/raw-os/nixos-current.efi
EFI/NixOS/raw-os/nixos-generation-1.efi
```

不需要再执行 `system.build.uki`、`system.build.rawOsBootEfi` 或其他内部 EFI 的独立构建命令来补充镜像内容。

<a id="raw-os-external-efi-build"></a>

### 初次构建外部固定 EFI

外部固定 EFI 与 raw 镜像是两个不同产物。它只在首次部署、外部启动逻辑发生变化或文件损坏时构建：

```bash
machine/raw_os/docs_script/creat-rawOsExternalBootEfi.sh -o ./nixos-img.efi
```

或者直接使用本仓库的 ` machine/raw_os/docs_script/nixos-img.efi`

将 `nixos-img.efi` 复制到宿主 ESP 的自定义路径，例如：

```text
EFI/NixOS/nixos-img.efi
```

然后使用目标机器的 UEFI 管理工具创建启动项，指向该文件。外部 EFI 不应覆盖宿主现有的 `EFI/BOOT/BOOTX64.EFI`，除非明确需要使用 fallback 路径。

宿主 NTFS 分区需要放置：

```text
OS-img/nixos.raw
```

外部启动链路和文件职责见：[Raw OS 引导架构与 UKI 说明](docs_script/UKI启动说明.md)。

### 直接写盘启动

将 `nixos.raw` 写入目标磁盘后，UEFI 会从镜像内部的 `EFI/BOOT/BOOTX64.EFI` 启动：

```bash
sudo dd if=./nixos.raw of=/dev/<target-disk> bs=16M status=progress conv=fsync
```

目标磁盘上的原有数据会被覆盖。直接写盘时不需要宿主 NTFS，也不需要外部固定 EFI。

### 从 NTFS 文件启动

从 NTFS 启动时，文件和启动项关系如下：

```text
宿主 ESP/EFI/NixOS/nixos-img.efi
    ↑ UEFI 启动项指向
宿主 NTFS/OS-img/nixos.raw
    ↑ 外部 EFI 搜索
raw 内部 EFI/NixOS/raw-os/grub.cfg
    ↑ 外部 EFI 通过 loopback 读取
raw 内部的当前或指定 generation UKI
```

外部 EFI 只负责：

- 搜索宿主 ESP 上的 Windows Boot Manager；
- 搜索 NTFS 中的 `/OS-img/nixos.raw`；
- 以 loopback 方式读取 raw 内部的 `EFI/NixOS/raw-os/grub.cfg`。

外部 EFI 不保存以下文件：

```text
nixos-current.efi
grub.cfg
nixos-generation-*.efi
```

因此，替换 NTFS 中的 `OS-img/nixos.raw` 后，外部固定 EFI 不需要变化。

<a id="raw-os-runtime-update"></a>

### Raw OS 内更新工作环境

以下命令必须在已经启动的 raw OS 内执行，并且在仓库根目录运行。根据实际硬件设置 `target`：AMD 使用 `raw_os_work_amd`，Intel 使用 `raw_os_work_intel`。

```bash
target=raw_os_work_amd
sudo nixos-rebuild switch \
  --flake ".#$target" \
  --option substituters https://cache.nixos.org
```

更新后，bootloader install hook 会更新 raw 内部：

```text
EFI/BOOT/BOOTX64.EFI
EFI/NixOS/raw-os/grub.cfg
EFI/NixOS/raw-os/nixos-current.efi
EFI/NixOS/raw-os/nixos-generation-*.efi
```

其中：

- 当前 generation 必须保留；
- `nixos-current.efi` 单独保留，不计入 generation 数量；
- generation UKI 按编号从新到旧最多保留 10 个；
- 新文件安装成功后才删除未选中的旧 generation 文件。

上述命令不会更新宿主 ESP 上的外部固定 EFI：

```text
宿主 ESP/EFI/NixOS/nixos-img.efi
```

### 重新构建外部固定 EFI

普通的 `nixos-rebuild switch`、generation 更新和 NTFS raw 镜像替换都不需要重新构建外部 EFI。只有以下情况需要重新执行[初次构建外部固定 EFI](#raw-os-external-efi-build)：

- 修改外部 GRUB 的 raw 搜索路径；
- 修改 raw 内部菜单路径；
- 修改外部 EFI 使用的 GRUB 模块；
- 更新 nixpkgs 后需要重新验证外部 EFI；
- 外部 EFI 文件损坏或需要重新部署。

### 替换 NTFS 中的 raw 镜像

构建并验证新的 `nixos.raw` 后，只替换宿主 NTFS 上的对应文件：

```text
宿主 NTFS/OS-img/nixos.raw
```

不要在普通更新时替换宿主 ESP 上的外部固定 EFI。替换镜像后，外部 EFI 会继续搜索相同路径，并读取新镜像内部的菜单和 UKI。

## 内部文件布局

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

## 测试、扩容和 QEMU

- 测试和验收流程见：[Raw OS 测试和验证方法](docs_script/测试和验证方法.md)。
- 引导链路、GRUB、UKI 和 initrd 服务说明见：[Raw OS 引导架构与 UKI 说明](docs_script/UKI启动说明.md)。
- raw 镜像扩容见：[raw 镜像扩容方法](docs_script/raw扩容方法.md)。
- QEMU 启动脚本和固件位于 `kvm-config/`。
