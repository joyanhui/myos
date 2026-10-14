{
  lib,
  username,
  ...
}:
{
  imports = [ ./raw-os-runtime.nix ];

  swapDevices = [ ];

  home-manager.users.${username} =
    { lib, ... }:
    {
      programs.brave.commandLineArgs = lib.mkForce [ "--password-store=basic" ];
    };
}
