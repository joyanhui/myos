{ config, pkgs, lib, ... }:
{
  # nixpkgs.overlays = [
  #   (final: prev: {
  #     bluez = prev.bluez.overrideAttrs (old: {
  #       patches = (old.patches or [ ]) ++ [
  #         ./bluez-fix-default-config-warning.patch
  #       ];
  #     });
  #   })
  # ];

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  services.blueman.enable = true;

  environment.systemPackages = with pkgs; [
    bluez
    bluez-tools
    bluetuith
  ];
}