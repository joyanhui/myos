{
  description = "<项目名> —— ESP32 固件开发编译环境";

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
        espPackages
        pythonPackages
        ;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = basePackages.all ++ espPackages.tools ++ pythonPackages.packages;
        env = espPackages.env;

        shellHook = ''
          export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin:$PATH"
          echo "== <项目名> devShell =="
          echo "  espflash = $(espflash --version 2>/dev/null)"
          echo "  烧录: espflash flash target/.../xxx.bin"
          if [ -t 0 ] && command -v nu >/dev/null 2>&1; then
            export __NUSHELL_DEVSHELL=1
            exec nu
          fi
        '';
      };
    };
}
