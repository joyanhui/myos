{
  description = "<项目名> —— Rust 开发编译环境";

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
        ;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = basePackages.all ++ rustPackages.packages;

        env = rustPackages.env;

        shellHook = ''
          export PATH="$HOME/.cargo/bin:/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$PATH"

          echo "==========================================================="
          echo "== <项目名> devShell =="
          echo "  Rust 工具链由 rustup 管理，首次进入请执行："
          echo "    rustup default stable"
          echo "==========================================================="
          if [ -t 0 ] && command -v nu >/dev/null 2>&1; then
            export __NUSHELL_DEVSHELL=1
            exec nu
          fi
        '';
      };
    };
}
