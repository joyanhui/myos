{ username
, ...
}:
{
  virtualisation.virtualbox.host.enable = true;
  virtualisation.virtualbox.host.enableExtensionPack = true;
  virtualisation.virtualbox.host.enableHardening = false; # https://github.com/NixOS/nixpkgs/issues/76108

  users.extraGroups.vboxusers.members = [ "${username}" ];
}
