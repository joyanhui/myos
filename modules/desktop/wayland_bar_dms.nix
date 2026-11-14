{ pkgs, username, global_settings, ... }:
{
  programs.dms-shell = {
    enable = true;
    systemd.enable = false;
    enableVPN = false;
    plugins.intervalCommand.src = pkgs.fetchFromGitHub {
      owner = "corcoran";
      repo = "dms-interval-command";
      rev = "6d071ad7795a0fbf5304cc760ef98083780fd1f5";
      hash = "sha256-9C/LkATxR9xpErKJr5EDx4GzCpaRojpHzxFoE54ii10=";
    };
  };

  home-manager.users.${username} = { config, ... }: {
    xdg.configFile."DankMaterialShell/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/dotfiles/dms_settings.json";
    xdg.configFile."DankMaterialShell/plugin_settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/dotfiles/dms_plugin_settings.json";
  };
}
