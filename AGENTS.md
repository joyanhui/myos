AI agents may read and reference this file, but MUST NEVER modify it in any way.Provide suggestions only; all changes require manual human editing.

本仓库使用 Nix Flakes 和 home-manager，支持 NixOS、WSL2、基于 glibc 的 Linux standalone 环境，以及 Raw OS 镜像和外部 EFI 产物。

仓库结构、host 清单、常用命令、Raw OS 流程和敏感信息完整规则见 `README.md`和其他相关文档。本文只规定开发和配置规则以及约束。

## 通用规则

- `mkOutOfStoreSymlink` 必须接收字符串路径，不能传入 Nix path literal，例如：`"${global_settings.repoDir}/..."`。
- 不新增注释；不得删除已有注释,尤其是特殊注释：基于保留旧代码或禁用配置项的目的的注释。
- 除非明确要求，不执行 `nix build` 或 `nixos-rebuild switch`。
- `global_setting_vars.nix` 是全局变量的唯一来源；`flake.nix` 通过 `specialArgs` 注入 `global_settings` 和 `username`。
- Nix 脚本必须直接读取 `REPO_DIR` 定位仓库，不得使用其他方式获取仓库路径，不得使用绝对路径(REPO_DIR除外)。

## 模块调度和特殊说明

- `wsl`、`tb_amd`、`raw_os_work_amd` 和 `raw_os_work_intel` 使用 `mkHost "tag1|tag2"` 构建。
- `raw_os_core_img_creat` 是用来创建可供虚拟机启动或者DD到硬盘启动 以及可以使用外部外部efi或者loop等方式直接启动的 raw格式的镜像构建，不参与nix flake host，不参与`nixos-rebuild`。
- `raw_os_work_amd` 和 `raw_os_work_intel` 是基于`raw_os_core_img_creat`构建的Raw OS 工作环境 AMD/Intel，通过 `amd` 和 `intel` tag 控制。
- NixOS/Nix 模块只能由 `app_and_modules_list_NixOS.nix`或者`app_and_modules_list_OtherLinux.nix` 调度，其他nix文件不得有对host/tag的判断。
- tag 白名单、`importIf` 和 `hasTag` 统一由 `module_list_lib.nix` 提供。
- 新增 tag 时，必须同步更新 `module_list_lib.nix` 和 `flake.nix`；未知 tag 必须显式失败，不得静默继续构建。
- 新增应用或服务时，在 `modules/` 中创建 `.nix` 文件，并在调度器中按 tag 加载。

- 在非nixos的Linux standalone 环境 防火墙、sshd、Docker、驱动等系统级功能由目标发行版管理，Nix 不管理这些内容。
- Linux standalone 的入口为 `homeConfigurations.linux`，由 `mkHome "common|dev|editor|ai|input-method|gui|dailyPC"` 构建。
- Linux standalone 的调度器为 `app_and_modules_list_OtherLinux.nix`：纯 home-manager 模块使用 `extract`；混合模块通过 `hmStandalone ? false` 选择输出模式。
- Linux standalone 的 nixpkgs 由 `flake.nix` 中的 `mkHome` 构造；不安全软件包列表来自 `global_settings.permittedInsecurePackages`。

## 敏感数据和环境变量

- 敏感信息统一由 transcrypt 管理，真实文件放在 `security/_protected/`，未解密时自动降级使用 `security/placeholder_files/` 的占位文件；完整规则见 [敏感信息说明](docs/敏感信息说明.md)。
- 所有敏感信息必须储存到 `.gitattributes` 加密规则包含的文件（`security/_protected/` 目录）。

## 开发环境模板

- `dev-env/flake.nix` 是项目级开发环境模板。
- 本仓库启用的开发环境由 `flake_pkgs_let.nix` 确定。
- 该模板的变更不得影响 `flake_pkgs_let.nix` 和 `flake_tpl_*.nix`可复制到其他独立项目中使用的能力。

## WSL 约束

- 必须设置 `wsl.wslConf.network.generateResolvConf = false`，由 NixOS 管理 `/etc/resolv.conf`。
- 必须设置 `wsl.interop.register = true`，避免 binfmt 影响 `.exe` 执行。
- 必须保留 WSLg 硬件 GPU 加速。
