# Raw OS

Raw OS 使用 NixOS 构建 GPT raw 镜像。镜像可以直接写入磁盘启动，也可以放在 NTFS 分区中，由宿主 ESP 上的外部固定 EFI 启动。

本文件是 Raw OS 的构建、部署和更新主文档。其他 Raw OS 文档只说明架构或测试方法，不重复维护构建命令。

<a id="raw-os-build-and-deploy"></a>

## 构建与部署

### host配置职责

- `raw_os_core_img_creat`
  - 基础镜像构建配置。
  - 生成初始 `nixos.raw`。
  - 为 raw 内部生成 `rawOsBootEfi`、菜单文件和初始 UKI。
  - 生成与硬件平台无关的基础系统，不包含完整日用环境，只有基本的的常用工具。
- `raw_os_work_intel/amd`
  - 运行在 raw OS 基础上的 AMD/Intel 工作环境配置。
  - 根据 `amd` 或 `intel` tag 启用对应的 IOMMU、KVM 和 VFIO 设置。
  - 用 `nixos-rebuild switch` 更新运行中的系统和 raw 内部 ESP。

### 产物和职责

| 产物                   | 构建来源                                            | 部署位置                                | 用途                             | 普通系统更新是否更新       |
| ---------------------- | --------------------------------------------------- | --------------------------------------- | -------------------------------- | -------------------------- |
| `nixos.raw`            | `raw_os_core_img_creat.config.system.build.image`   | 目标磁盘，或 NTFS 的 `OS-img/nixos.raw` | raw 系统镜像                     | 不直接更新；替换镜像时更新 |
| `rawOsExternalBootEfi` | `system.build.rawOsExternalBootEfi`                 | 宿主 ESP 的自定义 EFI 路径              | 搜索并加载 NTFS 中的 raw 镜像    | 否                         |

`nixos.raw` 内部包含 `rawOsBootEfi`、raw 内部菜单和 UKI：

```text
EFI/BOOT/BOOTX64.EFI
EFI/NixOS/raw-os/grub.cfg
EFI/NixOS/raw-os/nixos-current.efi
EFI/NixOS/raw-os/nixos-generation-*.efi
```


<a id="raw-os-initial-build"></a>

### 构建nixos.raw

以下命令是 Raw OS 初始构建的命令。构建完成后，命令会输出镜像目录，请从该目录手动复制 `nixos.raw`
到目标目录（宿主机的NTFS分区）：

```bash
nix build --no-link --print-out-paths .#nixosConfigurations.raw_os_core_img_creat.config.system.build.image
```

例如，若输出目录为 `/nix/store/...-nixos-disk-image`，执行：

```bash
cp --reflink=auto /nix/store/...-nixos-disk-image/nixos.raw /mnt/d/OS-img/nixos.raw
```

构建得到的 raw 镜像内部已经包含：`EFI/BOOT/BOOTX64.EFI  EFI/NixOS/raw-os/grub.cfg  EFI/NixOS/raw-os/nixos-current.efi  EFI/NixOS/raw-os/nixos-generation-1.efi`

<a id="raw-os-external-efi-build"></a>

### 构建外部固定 EFI(nixos-img.efi)

外部EFI用来在物理机器上搜索NTFS分区的nixos.raw并完成物理启动nixos。只在首次处理物理机引导时候构建和部署：

```bash
machine/raw_os/docs_script/creat-rawOsExternalBootEfi.sh -o ./nixos-img.efi
```

或者直接使用本仓库的 ` machine/raw_os/docs_script/nixos-img.efi`

将 `nixos-img.efi` 复制到宿主 ESP/EFI分区，例如：`EFI/NixOS/nixos-img.efi` 或 `EFI/BOOT/nixos-img.efi` 。

在win下可以使用DiskGenius找到自己的ESP分区把这个文件复制过去，然后用DiskGenius的工具里面的UEFI管理功能新增一个启动项指向这个文件。

外部启动链路和文件职责见：[Raw OS 引导架构与 UKI 说明](RawOS引导架构与UKI说明.md)。

### 直接写盘启动(写到U盘或者硬盘方式)

将 `nixos.raw` 写入目标磁盘后，UEFI 会从镜像内部的 `EFI/BOOT/BOOTX64.EFI` 启动：`sudo dd if=./nixos.raw of=/dev/<target-disk> bs=16M status=progress conv=fsync`

然后重启电脑，选择这个u盘/硬盘引导即可。此时不需要外部efi文件即可启动和正常安装的nixos系统一样使用。

### 使用物理机把nixos.raw模拟为一个真实的磁盘启动

- 把nixos.raw放到 物理机任意NTFS分区下的 /OS-img/nixos.raw
- 把外部efi`nixos-img.efi`放到物理机的ESP/EFI分区，并注册为UEFI引导项
- 开机选择这个新增的引导项启动,会自动完成如下启动流程
   - 搜索 `NTFS分区:/OS-img/nixos.raw`
   - 搜索物理机机上现有的Windows的引导文件
   - 加载nixos.raw内部efi分区的grub.cfg
   - 绘制一个 可以选择nixos不同generation 和 Windows 的可选启动菜单
   - 根据选择的启动项完成后续efi启动逻辑

### 虚拟机启动

以qemu在Windows的启动方法为例
```powershell
    & "C:\Program Files\qemu\qemu-system-x86_64.exe" `
      -machine q35,accel=whpx -cpu max -m 8G -smp 4 `
      -smbios type=11,value=io.systemd.stub.kernel-cmdline-extra=nomodeset `
      -bios N:\OS-img\OVMF.fd `
      -drive "if=virtio,format=raw,file=N:\OS-img\nixos.raw,cache=writeback" `
      -vga std -display sdl `
      -device qemu-xhci -device usb-tablet `
      -netdev user,id=net0  -device virtio-net-pci,netdev=net0 `
      -serial "file:N:\OS-img\qemu-serial.log"
```

- `-bios` 使用 4MB 合一的 `OVMF.fd`（`kvm-config/firmware/` 或 qemu 安装目录），变量每次启动重新枚举，不会进入 EFI shell。改用 pflash 对时，变量文件必须是 qemu 自带的 `share\edk2-i386-vars.fd`（528K），不能复用其他虚拟机的 `OVMF-vars.fd`，否则 OVMF 找不到可启动项会落到 EFI shell，需要手动输入 `FS0:\EFI\BOOT\BOOTX64.EFI`。
- `-smbios type=11,value=io.systemd.stub.kernel-cmdline-extra=nomodeset` 让 UKI 里的 systemd-stub 给内核追加 `nomodeset`：Windows 版 qemu 的本地窗口（sdl/gtk）在 guest 早期 KMS modeset 时会死锁，表现为卡在 `A start job is running for Load Kernel Modules` 且 qemu 窗口无响应；加 `nomodeset` 延后 modeset 后正常。
- 显卡用 `-vga std`。串口用 `-serial file:`，`-serial stdio` 在 Windows 控制台选中文本时会阻塞 guest 写串口。



<a id="raw-os-runtime-update"></a>

### Raw OS 内nixos-rebulid方法

以下命令必须在已经启动的 raw OS 内执行，并且在仓库根目录运行。根据实际硬件设置 `target`：AMD 使用 `raw_os_work_amd`，Intel 使用 `raw_os_work_intel`。

```bash
sudo nixos-rebuild switch --flake .#raw_os_work_amd \
  --option substituters https://cache.nixos.org
```


## 测试、扩容和 QEMU

- 测试和验收流程见：[Raw OS 测试和验证方法](RawOS测试与验证方法.md)。
- 引导链路、GRUB、UKI 和 initrd 服务说明见：[Raw OS 引导架构与 UKI 说明](RawOS引导架构与UKI说明.md)。
- raw 镜像扩容见：[raw 镜像扩容方法](Raw镜像扩容方法.md)。
- QEMU fd固件位于 `kvm-config/`,也可以自己从qemu安装目录获取。
