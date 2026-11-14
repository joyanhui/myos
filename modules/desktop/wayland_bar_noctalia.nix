{
  pkgs,
  username,
  global_settings,
  ...
}:
{
  home-manager.users.${username} = { config, ... }: {
    home.packages = [ pkgs.noctalia ];
    xdg.configFile."noctalia/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/dotfiles/noctalia_settings.json";
  };
}
