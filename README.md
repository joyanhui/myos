# myos

## Hosts

- `wsl`：WSL2 的 NixOS 配置。
- `tb_amd`：ThinkBook 14p AMD 配置。
- `raw_os_core_img_creat`：专用于创建可启动 raw 镜像和 UKI。
- `raw_os_work_amd`：raw OS AMD 工作环境。
- `raw_os_work_intel`：raw OS Intel 工作环境。
- `homeConfigurations.linux`：Debian、Ubuntu 等 glibc Linux 的 standalone 配置。

## 常用命令

```bash
# 应用 NixOS 配置
sudo nixos-rebuild switch --flake .#wsl
sudo nixos-rebuild switch --flake .#tb_amd --option substituters https://cache.nixos.org

# 创建 raw 镜像
nix build --no-link --print-out-paths \
  .#nixosConfigurations.raw_os_core_img_creat.config.system.build.image \
  --option substituters https://cache.nixos.org

# 创建 UKI
nix build --no-link --print-out-paths \
  .#nixosConfigurations.raw_os_core_img_creat.config.system.build.uki \
  --option substituters https://cache.nixos.org

# 构建 standalone home-manager
nix build .#homeConfigurations.linux.activationPackage
./result/activate
# 或
home-manager switch --flake .#linux
```

## 两个 list 文件

- `app_and_modules_list_NixOS.nix`：NixOS 模块调度器；根据 `moduleTags` 按 tag 加载系统模块。
- `app_and_modules_list_OtherLinux.nix`：standalone home-manager 模块调度器；根据 `moduleTags` 加载用户环境模块。
- NixOS host 的 tag 在 `flake.nix` 的 `mkHost` 中定义；standalone 的 tag 在 `mkHome` 中定义。
- tag 白名单、`importIf` 和 `hasTag` 统一由 `module_list_lib.nix` 提供。
