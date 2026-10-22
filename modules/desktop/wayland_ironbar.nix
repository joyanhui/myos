{ pkgs, username, global_settings, ... }:
{
  home-manager.users.${username} = { config, ... }: {
    home.packages = [ pkgs.ironbar ];
    xdg.configFile."ironbar/config.json".source =
      config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/dotfiles/ironbar_config.json";
    xdg.configFile."ironbar/style.css".source =
      config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/dotfiles/ironbar_style.css";
  };
}
