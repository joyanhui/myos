{
  description = "<项目名> —— Hugo (Go) 文档 / 博客开发环境";

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
        docsPackages
        ;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = basePackages.utils ++ docsPackages.hugo;

        shellHook = ''
          export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$PATH"
          echo "== <项目名> devShell =="
          echo "  hugo = $(hugo version 2>/dev/null | sed 's/Hugo Static Site Generator //') go = $(go version 2>/dev/null)"
          echo "  本地预览: hugo server -D"
          if [ -t 0 ] && command -v fish >/dev/null 2>&1; then
            export __FISH_DEVSHELL=1
            exec fish
          fi
        '';
      };
    };
}
