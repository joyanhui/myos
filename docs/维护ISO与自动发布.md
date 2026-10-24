# 维护 ISO 与自动发布

`iso_installer` 构建不含桌面环境的 NixOS 维护介质，提供网络、诊断、磁盘、文件系统和加密工具，支持 Flakes 和 `nix-command`，可用于物理机或云主机维护及重新安装。

## 手动构建

在仓库根目录执行：

```bash
nix build .#nixosConfigurations.iso_installer.config.system.build.isoImage
```

ISO 位于 `result/iso/`。此配置依赖仓库的 flake 输入，首次构建需要网络。介质同时支持 BIOS 和 UEFI；控制台串口为 `ttyS0,115200n8`。

默认安装介质账户为 `nixos`，本地控制台自动登录。root 与 nixos 初始均无可用密码；SSH 开启但禁止 root 登录。远程登录前应通过控制台设置 `nixos` 密码，或以安全方式配置其 SSH 公钥。不要将个人 SSH 密钥或密码写进镜像配置。

## GitHub Release

仓库的 `Build and release system images` 工作流提供 `workflow_dispatch` 手动运行，并在每周一检查默认分支。定时工作流只有在默认分支提交与上次成功发布镜像的提交不同时才构建；首次发布会正常构建。构建产物包含：

- `nixos.raw.7z` 或多个 `nixos.raw.7z.001` 等分卷，解压得到 `nixos.raw`。
- `nixos-img.efi`，搜索外置 NTFS 分区 Raw OS 镜像的 EFI 文件。
- `iso-installer-x86_64-linux.iso`，维护与重装介质。
- `SHA256SUMS`，资产校验清单。

下载所有同一 Release 的 raw 归档分卷到同一目录后，使用 7-Zip 测试和解压，例如 `7z t nixos.raw.7z.001`、`7z x nixos.raw.7z.001`。单卷归档文件名为 `nixos.raw.7z`，可直接测试和解压。发布前工作流检查归档、分卷和校验和；每个资产均限制在 GitHub Release 单文件大小限制内。

校验发布文件：

```bash
sha256sum -c SHA256SUMS
```

Raw 镜像的启动及部署说明见 [Raw OS 主文档](RawOS说明.md)。ISO 内置空密码，不适用于不可信网络环境中的无防护远程暴露；操作前确认目标磁盘并自行备份，介质不会自动清盘或重装。
