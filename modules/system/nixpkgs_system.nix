{ lib, inputs, global_settings, ... }:
let
  stateVersion = global_settings.stateVersion;
  nixpkgsConfig = {
    allowUnfree = true;
    allowBroken = true;
    permittedInsecurePackages = global_settings.permittedInsecurePackages;
  };
in
{
  nix.settings.experimental-features = "nix-command flakes";
  nix.settings.substituters = lib.mkForce [
    "https://mirror.sjtu.edu.cn/nix-channels/store"
    "https://mirrors.ustc.edu.cn/nix-channels/store"
    "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
  ];
  nixpkgs.config = nixpkgsConfig;
  nixpkgs.overlays = [
    (
      final: prev:
      let
        importNixpkgs =
          nixpkgsInput:
          import nixpkgsInput {
            system = prev.stdenv.hostPlatform.system;
            config = nixpkgsConfig;
          };
      in
      {
        unstable = importNixpkgs inputs.nixpkgs-unstable;
      }
    )
  ];
  documentation.nixos.enable = false;
  system.stateVersion = stateVersion;
  time.timeZone = "Asia/Shanghai";
  systemd.settings.Manager.RebootWatchdogSec = "10s";
  systemd.services.dbus-broker = {
    serviceConfig.TimeoutStartSec = 180;
  };
  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];
  };
  nix.settings.trusted-users = [
    "root" # nix flake update --option substituters https://mirrors.sjtug.sjtu.edu.cn/nix-channels/store/
    "nixos"
  ];
  nix.settings.trusted-substituters = [
    "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store?priority=10"
    "https://mirrors.ustc.edu.cn/nix-channels/store?priority=10"
    "https://mirrors.sjtug.sjtu.edu.cn/nix-channels/store?priority=35"
    "https://nix-mirror.freetls.fastly.net?priority=11"
    "https://cache.nixos.org?priority=12"
    "https://nix-community.cachix.org?priority=13"
    "https://nixpkgs-wayland.cachix.org"
    "https://cache.lix.systems"
  ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
    "cache.lix.systems:aBnZUw8zA7H35Cz2RyKFVs3H4PlGTLawyY5KRbvJR8o="
  ];

}
