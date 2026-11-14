{
  pkgs,
  username,
  global_settings,
  ...
}:
{
  home-manager.users.${username} = { config, ... }: {
    home.packages = [ pkgs.noctalia ];
    xdg.configFile."noctalia/config.toml".source =
      config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/dotfiles/noctalia_config.toml";
    home.file.".local/share/noctalia/plugins/bar-scripts/plugin.toml".source =
      config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/dotfiles/noctalia_plugins_bar_scripts.toml";
    home.file.".local/share/noctalia/plugins/bar-scripts/widget.luau".source =
      config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/dotfiles/noctalia_plugins_bar_scripts.luau";
  };
}
