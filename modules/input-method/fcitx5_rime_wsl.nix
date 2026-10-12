{ username, lib, ... }:
{
  home-manager.users.${username}.systemd.user.services.fcitx5 = {
    Unit.PartOf = lib.mkForce [ ];
    Install.WantedBy = lib.mkForce [ "default.target" ];
  };
}