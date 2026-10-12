# 如何迁移pi

## 先装pi

- 安装 pnpm，然后 `pnpm add -g @earendil-works/pi-coding-agent`，验证 `pi --version`。

## 迁移pi的配置和记忆

思路：关闭 WSL，在 Linux 侧挂载 wsl 的 vhdx，把 vhdx 内部 `/home/nixos/` 下 pi 的运行时数据和记忆库复制到新机器对应目录。

### 1. 关闭WSL并找到vhdx

- 在 Windows PowerShell 执行 `wsl --shutdown`，保证 vhdx 处于一致状态。
- vhdx 路径：`%LOCALAPPDATA%\Packages\<发行版>\LocalState\ext4.vhdx`，发行版名用 `wsl -l -v` 查（如 `CanonicalGroupLimited.Ubuntu24.04LTS`）。

### 2. 挂载vhdx所在分区

vhdx 文件本身在 Windows 分区或外置盘上，先挂载它所在的分区：

- Windows 系统分区（NTFS），用 `sudo lsblk -f` 确认设备（如 `/dev/nvme0n1p3`）：`sudo mount -t ntfs3 /dev/nvme0n1p3 /mnt/win`（内核 5.15+ 自带 ntfs3）；旧内核用 `nix shell nixpkgs#ntfs3g` 后 `sudo mount -t ntfs-3g /dev/nvme0n1p3 /mnt/win`。
- vhdx 在该分区内的路径：`/mnt/win/Users/<用户>/AppData/Local/Packages/<发行版>/LocalState/ext4.vhdx`。
- vhdx 拷贝到外置盘时，按盘的实际文件系统挂载该盘分区，再取 vhdx 路径。

### 3. 挂载vhdx文件

qemu-nbd（可读写挂载）

- `nix shell nixpkgs#qemu` 提供 qemu-nbd；若内核无 nbd 模块，在配置中加 `boot.kernelModules = [ "nbd" ]` 后重建，或临时 `modprobe nbd`
- `sudo qemu-nbd -c /dev/nbd0 /path/to/ext4.vhdx`
- `sudo partprobe /dev/nbd0`，然后 `sudo fdisk -l /dev/nbd0` 看是否有分区表：无分区表直接 `mount /dev/nbd0 /mnt/wsl`，有分区表挂 `/dev/nbd0p1`。
- 用完 `sudo umount /mnt/wsl && sudo qemu-nbd -d /dev/nbd0`

### 4. 复制哪些文件

源路径均在 vhdx 内的 `/home/nixos/` 下；目标为同一份相对路径，下面统一用 `~` 表示新机器家目录。

必须复制：

- `~/.pi/agent/`（对应仓库 `modules/ai/cfg_pi/`）下的全部内容：配置文件 auth.json / settings.json / mcp.json / models.json / trust.json / web-search.json / context.md / settings.json.bak，会话记忆 `sessions/`（135M），运行时数据 `models-store.json`、`pi-subagents-state/`、`missions/`、`web-search-cache/`、`crashes.json`、`run-history.jsonl`、`pi-chrome-devtools.json`、`agents/.glla-subagent-sync.json`；`npm/` 是 pi 运行时 node_modules（938M，体积大头，网络好可跳过让 pi 重装）；`SYSTEM.md` 是软链可跳过。
- `~/.pi/web-search-cache/`（真实目录，不在 agent 软链内）。
- `~/.local/share/cortexkit/magic-context/`（整个目录，pi 的记忆库 context.db，与 opencode 共用，约 201M，包含 context.db / context.db-wal / context.db-shm / project-identities / pi-served-array-digests / models 等）。
- `~/.config/cortexkit/magic-context.jsonc`。

不用复制：

- `SYSTEM.md`（软链，激活时重建）。
- `~/.agents/skills`（软链到仓库 `modules/ai/skill`）。
- pi 程序本体（步骤一已重装）。

复制命令：

- rsync 临时使用：`nix shell nixpkgs#rsync`（系统未装时）
- `rsync -aL /mnt/wsl/home/nixos/.pi/ ~/.pi/`
- `rsync -a /mnt/wsl/home/nixos/.local/share/cortexkit/magic-context/ ~/.local/share/cortexkit/magic-context/`
- `rsync -a /mnt/wsl/home/nixos/.config/cortexkit/magic-context.jsonc ~/.config/cortexkit/magic-context.jsonc`
