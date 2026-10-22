{ pkgs, username, global_settings, ... }:
{
  home-manager.users.${username} = { config, ... }: {
    home.packages = [ pkgs.waybar ];
    xdg.configFile."waybar/config.jsonc".source =
      config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/dotfiles/waybar_config.jsonc";
    xdg.configFile."waybar/style.css".source =
      config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/dotfiles/waybar_style.css";
  };
}
