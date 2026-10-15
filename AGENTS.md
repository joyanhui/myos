# AGENTS.md

本仓库使用 Nix Flakes 和 home-manager，服务于 NixOS、WSL2 以及基于 glibc 的 Linux standalone 环境。

当前 flake 输出：

- NixOS：`wsl`、`tb_amd`、`raw_os_core_img_creat`（做可启动镜像专用）、`raw_os_work_amd`、`raw_os_work_intel`
- standalone：`homeConfigurations.linux`

## 基本规则

- 交流使用中文；commit message、函数名、注释、日志和错误信息使用英文。
- Nix 文件使用相对路径，禁止 `/home/...` 等绝对路径；`mkOutOfStoreSymlink` 按下文规则执行。
- 不新增注释，也不要删除已有的旧代码注释或禁用配置。
- 除非用户明确要求，不主动执行长时间的`nix build`或 `nixos-rebuild switch`。

## NixOS 主机和模块

- `wsl`、`tb_amd`、`raw_os_work_amd`、`raw_os_work_intel` 使用 `mkHost "tag1|tag2"`；`raw_os_core_img_creat` 使用独立的 raw OS 镜像构建模块。raw work 的 AMD/Intel 平台差异由 `app_and_modules_list_NixOS.nix` 中的 `raw-amd`、`raw-intel` tag 控制。
- NixOS 模块由 `app_and_modules_list_NixOS.nix` 按 tag 加载；tag 白名单、`importIf` 和 `hasTag` 定义在 `module_list_lib.nix`。
- 不得在 两个 list_xx.nix 文件之外 有任何判断 tag和host的逻辑，所有判断必须集中在两个xx_list_xxx.nix文件内完成。
- 新增 tag 时同步修改 `module_list_lib.nix` 和 `flake.nix`；未知 tag 必须显式失败，禁止带病构建。
- 新增应用或服务时，在 `modules/` 中创建 `.nix` 文件，并在调度器中按 tag 加载。

唯一的窗口管理器是 niri，Hyprland 已移除，仓库不使用 display manager：

- `tb_amd`：TTY 登录后执行 `niri-session`。
- `wsl`：直接执行 `niri`。

niri 配置通过 `spawn-sh-at-startup` 导入会话环境并重启 `fcitx5`；`Mod+Shift+R` 执行同样的重启动作。

## 非 NixOS standalone

- 支持 Debian、Ubuntu 等 glibc x86_64 系统；不支持 Alpine、OpenWrt 等 musl 系统。
- 系统级功能（防火墙、sshd、Docker 等）由目标发行版管理。
- standalone 入口是 `homeConfigurations.linux`，由 `mkHome "common|dev|editor|ai|input-method|gui|dailyPC"` 构建。
- 调度器是 `app_and_modules_list_OtherLinux.nix`；纯 home-manager 模块使用 `extract`，混合模块通过 `hmStandalone ? false` 选择输出模式。
- standalone 的 nixpkgs 由 `flake.nix` 中的 `mkHome` 构造，不安全软件包列表来自 `global_settings.permittedInsecurePackages`。

```sh
nix build .#homeConfigurations.linux.activationPackage
./result/activate
```

更新可重复上述流程，或执行 `home-manager switch --flake .#linux`。

standalone 的 mihomo要考虑tun权限 ，并作为用户服务运行。fcitx5 由 home-manager 写入 `~/.config/systemd/user/`，wrapper 根据 niri、WSLg 或普通桌面选择 `waylandim` 参数；其启动方式以实际生成的服务和会话依赖为准。环境变量通过 `home.sessionVariables`、`home.sessionPath` 和 `environment.d` 注入。

## 构建命令

```sh
sudo nixos-rebuild switch --flake .#wsl
sudo nixos-rebuild switch --flake .#tb_amd --option substituters https://cache.nixos.org
```

## 敏感数据和环境变量

敏感信息和环境变量规则统一见 [README.md 的敏感信息说明](README.md#security-secrets)，本文件不重复维护。执行任务时必须遵守该说明。

## 写法约定

- `mkOutOfStoreSymlink` 必须接收字符串路径，例如 `"${global_settings.repoDir}/..."`，不能传 Nix path literal。
- `global_setting_vars.nix` 是全局变量唯一来源；`flake.nix` 通过 `specialArgs` 注入 `global_settings` 和 `username`。
- nix脚本直接读取 `REPO_DIR` 定位仓库，不得使用其他方式获取路径。
- `dev-env/flake.nix` 是项目级开发环境模板，通过flake_pkgs_let.nix确定启用的环境。这两个可以复制到其他独立项目中作为模板使用。

## WSL 专用规则

- `wsl.wslConf.network.generateResolvConf = false`，由 NixOS 管理 `/etc/resolv.conf`。
- `wsl.interop.register = true`，避免 binfmt 影响 `.exe` 执行。
- 必须保留 WSLg 硬件 GPU 加速。

## 目录结构

```
├── flake.nix                  # 入口，定义 inputs、NixOS 与 home-manager 输出
├── flake.lock / .gitignore
├── global_setting_vars.nix    # 全局配置变量集中定义（路径、代理、密钥、字体等）
├── module_list_lib.nix        # tag 白名单及 importIf/hasTag 辅助函数
├── app_and_modules_list_NixOS.nix      # NixOS 模块调度中心，按 tag 条件加载
├── app_and_modules_list_OtherLinux.nix # 非 NixOS standalone 模块调度中心
├── dev-env/                   # 项目级开发环境模板（flake_pkgs_let + flake_tpl_*）
├── machine/                   # 机器配置（每台机器一个目录或文件）
│   ├── tb_amd/                # ThinkBook 14p AMD 的硬件和机器配置
│   ├── raw_os/                # raw OS 核心和工作环境配置
│   ├── server_template/       # 服务器配置模板
│   ├── wsl.nix                # WSL 入口，导入 nixos-wsl 模块
│   └── livecd_w_base.nix      # Live CD 基础配置
├── modules/
│   ├── system/                # 系统全局：环境变量、用户、Nix、网络、防火墙、引导、字体、主题、存储
│   ├── desktop/               # 桌面会话：Wayland、niri、锁屏、DMS、截图及相关配置文件
│   ├── term/                  # shell、终端、命令行工具和 shell 配置
│   ├── services/              # SSH、定时任务、数据库、虚拟化、网络服务和其他系统服务
│   ├── apps/                  # 浏览器、即时通信、文件管理、办公、媒体、兼容层和远程工具
│   ├── dev/                   # 开发环境、编辑器、Git、语言运行时和开发工具
│   ├── input-method/          # fcitx5、Rime 和语音输入配置
│   └── ai/                    # AI 工具、模型配置、MCP、Pi 和 skills
├── security/                  # 敏感文件目录，规则见 README.md 的敏感信息说明
├── script/                    # 自动化脚本和辅助程序
├── static_file/               # 壁纸、图标、锁屏壁纸和其他静态资源
├── kvm-config/                # 虚拟机脚本和固件：qemu_*.sh、download.sh、firmware/
├── lyndon_win11/              # Win11 相关的 AutoHotkey 和 dotfile
├── nixpkgs-config/            # Nixpkgs 配置预留目录
└── nixos_install.md           # NixOS 安装说明
```
