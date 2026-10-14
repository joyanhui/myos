{
  description = "<项目名> —— 全量开发编译环境（Rust / Tauri / Flutter / Android / ESP32 / Bun / Go / Zig / Python / Hugo / Ruby / CF）";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs =
    { nixpkgs, ... }:
    let
      env = import ./flake_pkgs_let.nix { inherit nixpkgs; };
      inherit (env)
        system
        pkgs
        basePackages
        jsPackages
        playwrightPackages
        rustPackages
        desktopPackages
        espPackages
        docsPackages
        golangPackages
        zigPackages
        pythonPackages
        flutterPackages
        android
        ;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages =
          basePackages.all
          ++ jsPackages
          ++ playwrightPackages
          ++ rustPackages.packages
          ++ desktopPackages.packages
          ++ espPackages.tools
          ++ docsPackages.all
          ++ golangPackages.packages
          ++ zigPackages
          ++ pythonPackages.packages
          ++ flutterPackages
          ++ android.packages;

        env = rustPackages.env // desktopPackages.env // android.env // golangPackages.env // espPackages.env // {
          LD_LIBRARY_PATH = "${rustPackages.env.LD_LIBRARY_PATH}:${espPackages.env.LD_LIBRARY_PATH}";
        };

        shellHook = ''
          export PATH="$HOME/.cargo/bin:/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$PATH"

          echo "==========================================================="
          echo "== <项目名> devShell（全量） =="
          echo "  Rust 工具链由 rustup 管理，首次进入请执行："
          echo "    rustup default stable"
          echo "  bun 依赖："
          echo "    bun install"
          echo "==========================================================="
          if [ -t 0 ] && command -v nu >/dev/null 2>&1; then
            export __NUSHELL_DEVSHELL=1
            exec nu
          fi
        '';
      };
    };
}
