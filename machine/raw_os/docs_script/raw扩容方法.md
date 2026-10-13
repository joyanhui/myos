# raw 镜像扩容方法

使用 `resize-raw-image.ps1` 对 GPT 格式的 raw 磁盘镜像进行扩容（分区表 + 分区 2 + Btrfs 文件系统）。

## 依赖

- Windows 环境（PowerShell 5.1+，脚本使用 .NET `System.IO.FileStream`，无需额外安装）
- 待扩容的镜像：GPT 分区表，分区 2 存在且包含 Btrfs 文件系统（如 NixOS 镜像）
- 磁盘剩余空间 ≥ 目标大小（稀疏文件，实际占用按内容增长）

## 调用脚本的命令

```powershell
# 扩容到 100G（同时扩容分区 2 和 Btrfs 文件系统）
powershell.exe -NoProfile -ExecutionPolicy Bypass -File resize-raw-image.ps1 `
  -ImagePath nixos.raw -NewSize 100G -ResizeBtrfs
```

参数说明：

| 参数 | 必填 | 说明 |
|------|------|------|
| `-ImagePath` | 是 | 镜像文件路径 |
| `-NewSize` | 是 | 目标大小，支持 K/M/G/T/P 单位，如 `100G`（需大于当前大小） |
| `-ResizeBtrfs` | 否 | 同步扩容分区 2 内的 Btrfs 文件系统 |
| `-SkipBtrfsResize` | 否 | 跳过 Btrfs 扩容（与 `-ResizeBtrfs` 互斥） |

失败时脚本自动回滚镜像至原状。

## 验证方法

```powershell
# 1. 检查镜像文件大小（应为 100 GiB = 107374182400 字节）
Get-Item nixos.raw | Select-Object Length

# 2. 在 Linux 侧验证 GPT 分区表和文件系统
lsblk -f nixos.raw
sudo parted nixos.raw print            # 查看分区 2 大小
sudo btrfs filesystem show nixos.raw   # 查看 Btrfs 容量（约 99 GiB）
```

或直接挂载/启动镜像，在系统内确认 `df -h /` 显示约 99G。
