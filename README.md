# myos

支持 NixOS系统管理；支持其他 Linux 发行版的nixpkgs；支持构建可引导的 raw 镜像和外部 EFI。

## Hosts

- `wsl`：WSL2 的 NixOS 配置。
- `tb_amd`：ThinkBook 14p AMD 配置。
- `raw_os_core_img_creat`：Raw OS 基础镜像构建配置，生成初始 raw 镜像以及内部、外部引导产物，不绑定 AMD 或 Intel 工作环境。
- `raw_os_work_amd`：运行在 raw 镜像内的 AMD 工作环境配置，包含 AMD IOMMU、KVM 和 VFIO 设置。
- `raw_os_work_intel`：运行在 raw 镜像内的 Intel 工作环境配置，包含 Intel IOMMU、KVM 和 VFIO 设置。
- `homeConfigurations.linux`：Debian、Ubuntu 等基于 glibc Linux 的 standalone 配置。

## 常用命令

### 应用 NixOS 配置

```bash
# 应用 NixOS 配置
sudo nixos-rebuild switch --flake .#wsl
sudo nixos-rebuild switch --flake .#raw_os_work_amd
sudo nixos-rebuild switch --flake .#tb_amd --option substituters https://cache.nixos.org
```

### 在其他发行版 nix home-manager standalone

```bash
nix build .#homeConfigurations.linux.activationPackage
./result/activate
# 或
home-manager switch --flake .#linux
```

### Raw OS

Raw OS 的构建、部署和运行时更新命令统一维护在 [Raw OS 主文档](machine/raw_os/README.md#raw-os-build-and-deploy)。不要在其他文档中复制 Raw OS 构建命令。

- [Raw OS 主文档](machine/raw_os/README.md)
- [Raw OS 引导架构与 UKI 说明](machine/raw_os/docs_script/UKI启动说明.md)
- [Raw OS 测试和验证方法](machine/raw_os/docs_script/测试和验证方法.md)

## 功能调度

使用两个 list 文件，根据 host 关联的 tag 来调度模块。

- `app_and_modules_list_NixOS.nix`：NixOS 模块调度器；根据 `moduleTags` 按 tag 加载系统模块。
- `app_and_modules_list_OtherLinux.nix`：standalone home-manager 模块调度器；根据 `moduleTags` 加载用户环境模块。
- NixOS host 的 tag 在 `flake.nix` 的 `mkHost` 中定义；standalone 的 tag 在 `mkHome` 中定义。
- tag 白名单、`importIf` 和 `hasTag` 统一由 `module_list_lib.nix` 提供。

<a id="security-secrets"></a>

## 敏感信息

本仓库使用 transcrypt 管理敏感信息。敏感真值集中放置在 `security/_protected/`，提交到仓库的内容受到 transcrypt 加密保护；工作区解密后的文件仅供本地使用。

新克隆仓库后，在仓库根目录执行`transcrypt -c aes-256-cbc` 然后输入密码解密，如果已经解密可以重新加密。

### 如果没有密码

nix会自动根据`cat security/_protected/isDecryptedCheckFileLen.txt`判断是否解密，未解密时自动使用 `security/placeholder_files/` 中的占位文件完成系统构建。

- 不影响系统构建和日常使用
- mihomo配置文件中的订阅地址为占位符
- 环境变量中的敏感token/key等为占位符
- pi/opencode等配置为占位符
- rclone 等文件的配置为占位符

如何自己加密：

```bash
# 用占位文件覆盖加密的文件
cp -rf security/placeholder_files/. security/_protected/
# 编辑 security/_protected/ 下的文件 为自己的
# ....
# 加密
transcrypt
# 推送到自己的git
```

### 敏感文件约束

- 真实敏感文件只能放在 `security/_protected/`，占位文件放在 `security/placeholder_files/`。
- 新增敏感文件后，必须确认 `.gitattributes` 使用 `filter=crypt diff=crypt merge=crypt`，不得把真实敏感值放入源码、flake、模块、脚本、文档、示例或构建产物。
- transcrypt 密码只能由使用者交互输入并保存在本地 Git 配置中，不得提交密码、解密后的副本或临时导出文件。
- 提交前必须检查 transcrypt 属性和暂存区内容；如果凭据曾进入 Git 历史，必须先轮换凭据，再清理历史并确认远程仓库不再保留旧对象。
- 非敏感环境变量只在 `modules/system/env_manager.nix` 的 `envVars` 中定义；敏感环境变量只在 `security/_protected/sensitive_env.nix` 中定义，并在 `security/placeholder_files/sensitive_env.nix` 中使用脱敏占位值。
