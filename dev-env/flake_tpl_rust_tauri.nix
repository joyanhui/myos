{
  description = "<项目名> —— Rust + Tauri (Linux x86) + Android APK + Bun 前端 开发编译环境";

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
        rustPackages
        desktopPackages
        android
        jsPackages
        ;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages =
          basePackages.all
          ++ rustPackages.packages
          ++ desktopPackages.packages
          ++ android.packages
          ++ jsPackages;

        env = rustPackages.env // desktopPackages.env // android.env;

        shellHook = ''
          export PATH="$HOME/.cargo/bin:/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$PATH"

          echo "==========================================================="
          echo "== <项目名> devShell =="
          echo "  Rust 工具链由 rustup 管理，首次进入请执行："
          echo "    rustup default stable"
          echo "  bun 依赖："
          echo "    bun install"
          echo "==========================================================="
          if [ -t 0 ] && command -v fish >/dev/null 2>&1; then
            export __FISH_DEVSHELL=1
            exec fish
          fi
        '';
      };
    };
}
