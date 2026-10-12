{
  pkgs,
  username,
  lib,
  config,
  global_settings,
  hmStandalone ? false,
  ...
}:
let
  flakeNixDevEnv = import ../../dev-env/flake_pkgs_let.nix { nixpkgs = pkgs.path; };
  readme = "
  # 系统级引入 flake_pkgs_let.nix 的全部包（仅 packages，不含 env）
  #
  # 目的：
  #   - devShell 的包不在系统闭包内，nix-collect-garbage 会清掉开发环境依赖；
  #     这里把全部开发包挂进系统，避免被 GC 清理（包已缓存，进入 devShell 即用）。
  #   - 仅引入 packages，不注入环境变量，防止污染日用环境。（例外：npm 全局
  #     prefix 因 Nix store 只读，必须经模块注入，见下方 config.nodejs）";
  devPkgs = lib.concatLists (
    with flakeNixDevEnv;
    [
      basePackages.all
      languagePackages.packages
      playwrightPackages
      rustPackages.packages
      desktopPackages.packages
      espPackages.tools
      docsPackages.all
      golangPackages.packages
      zigPackages
      pythonPackages.packages
      flutterPackages
    ]
  );
  devEnvAll = pkgs.buildEnv {
    name = "hm-dev-all";
    paths = devPkgs;
    ignoreCollisions = true;
    meta.priority = 20;
  };
in
if hmStandalone then
  {
    home.packages = [ devEnvAll ];

    xdg.configFile = {
      "flakeNixReadMe.md".text = readme;
    };
  }
else
  {
    environment.systemPackages = devPkgs;

    home-manager.users.${username} = { config, ... }: {

      xdg.configFile = {
        "flakeNixReadMe.md".text = readme;
      };
    };
  }