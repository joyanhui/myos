{
  pkgs,
  lib,
  username,
  global_settings,
  ...
}:
{
  programs.dms-shell = {
    enable = true;
    systemd.enable = false;
    enableVPN = false;
  };

  home-manager.users.${username} =
    { config, ... }:
    {
      xdg.configFile."DankMaterialShell/".source =
        config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/modules/desktop/configFile/DankMaterialShell";
    };
}