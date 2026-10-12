{
  description = "<项目名> —— Go 开发编译环境（含国内镜像）";

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
        golangPackages
        ;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = basePackages.utils ++ golangPackages.packages;

        env = golangPackages.env;

        shellHook = ''
          export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$PATH"
          echo "== <项目名> devShell =="
          echo "  go = $(go version 2>/dev/null) gopls = $(gopls version 2>/dev/null | cut -d' ' -f2)"
          echo "  GOPROXY = $(go env GOPROXY)"
          if [ -t 0 ] && command -v fish >/dev/null 2>&1; then
            export __FISH_DEVSHELL=1
            exec fish
          fi
        '';
      };
    };
}
