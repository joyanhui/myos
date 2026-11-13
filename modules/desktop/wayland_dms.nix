{ pkgs, username, global_settings, ... }:
let
  pluginSettings = {
    intervalCommand = {
      enabled = true;
      variants = [
        {
          id = "weather";
          name = "Weather";
          command = "bar-weather --text";
          icon = "partly_cloudy_day";
          refreshInterval = 300;
          clickCommand = "bar-weather --detail";
          popoutEnabled = false;
          useAccentColor = false;
          tabularNumbers = false;
        }
        {
          id = "lunar";
          name = "Lunar";
          command = "bar-lunar";
          icon = "calendar_month";
          refreshInterval = 60;
          clickCommand = "bar-lunar --calendar";
          popoutEnabled = false;
          useAccentColor = false;
          tabularNumbers = false;
        }
      ];
    };
  };
in
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
    xdg.configFile."DankMaterialShell/plugin_settings.json".text = builtins.toJSON pluginSettings;
  };
}
