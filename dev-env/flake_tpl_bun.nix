{
  description = "<项目名> —— Bun / TypeScript + Cloudflare Worker 开发环境";

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
        ;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = basePackages.all ++ jsPackages;

        shellHook = ''
          export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$PATH"
          echo "== <项目名> devShell =="
          echo "  bun = $(bun --version 2>/dev/null) wrangler = $(bunx wrangler --version 2>/dev/null)"
          echo "  本地开发: bun dev；wrangler 用 bunx/npx wrangler 按需调用"
          if [ -t 0 ] && command -v fish >/dev/null 2>&1; then
            export __FISH_DEVSHELL=1
            exec fish
          fi
        '';
      };
    };
}
