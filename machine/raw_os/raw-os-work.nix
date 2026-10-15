{
  lib,
  username,
  ...
}:
{
  imports = [ ./raw-os-runtime.nix ];

  swapDevices = [ ];

  services.getty.autologinUser = lib.mkForce null;

  home-manager.users.${username} =
    { lib, ... }:
    {
      programs.brave.commandLineArgs = lib.mkForce [ "--password-store=basic" ];
    };
}
