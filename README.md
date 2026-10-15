# myos

基于nixos，支持其他linux发行版，支持构建可以引导的raw文件和外部efi

## Hosts

- `wsl`：WSL2 的 NixOS 配置。
- `tb_amd`：ThinkBook 14p AMD 配置。
- `raw_os_core_img_creat`：专用于创建可启动 raw 镜像和 内部esp的引导和外部efi（无视硬件差异）。
- `raw_os_work_amd`：raw OS AMD 工作环境，运行在raw镜像上，基于amd的优化，支持kvm直通等。
- `raw_os_work_intel`：raw OS Intel 工作环境，运行在raw镜像上，基于intel优化，支持kvm直通。
- `homeConfigurations.linux`：Debian、Ubuntu 等基于 glibc Linux 的 standalone 配置。

## 常用命令

```bash
# 应用 NixOS 配置
sudo nixos-rebuild switch --flake .#wsl
sudo nixos-rebuild switch --flake .#tb_amd --option substituters https://cache.nixos.org
# 基于raw os的两个日用环境配置
sudo nixos-rebuild switch --flake .#raw_os_work_amd --option substituters https://cache.nixos.org
sudo nixos-rebuild switch --flake .#raw_os_work_intel --option substituters https://cache.nixos.org

# raw work 按硬件平台选择 AMD 或 Intel 配置

# 创建 raw 镜像 和 UKI ，更多说明需要参考 machine/raw_os 下的nix和文档
nix build --no-link --print-out-paths \
  .#nixosConfigurations.raw_os_core_img_creat.config.system.build.image \
  --option substituters https://cache.nixos.org
nix build --no-link --print-out-paths \
  .#nixosConfigurations.raw_os_core_img_creat.config.system.build.uki \
  --option substituters https://cache.nixos.org

# 构建 standalone home-manager
nix build .#homeConfigurations.linux.activationPackage
./result/activate
# 或
home-manager switch --flake .#linux
```

## 功能调度

使用两个list文件，根据host关联的tag来判读调度

- `app_and_modules_list_NixOS.nix`：NixOS 模块调度器；根据 `moduleTags` 按 tag 加载系统模块。
- `app_and_modules_list_OtherLinux.nix`：standalone home-manager 模块调度器；根据 `moduleTags` 加载用户环境模块。
- NixOS host 的 tag 在 `flake.nix` 的 `mkHost` 中定义；standalone 的 tag 在 `mkHome` 中定义。
- tag 白名单、`importIf` 和 `hasTag` 统一由 `module_list_lib.nix` 提供。

## 敏感信息

本仓库使用 git-crypt 来加密敏感信息，敏感信息集中放置在`security\_protected` 目录，在没有key解密的情况自动降级到使用`security\placeholder_files`的占位文件文件来完成系统的构建，以及环境变量注入用户账号密码等信息。
自动判定方式是通过判断一个文件 isDecryptedCheckFileLen.txt 的内容是不是`1`|`1\n`来实现。

git clone ，在仓库内 运行 `transcrypt -c aes-256-cbc` cipher可忽略 直接运行`transcrypt` 会自动解密加密的文件，提交的时候会自动解密

本仓库约定所有敏感信息都放到 `security\_protected`目录
