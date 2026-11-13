{ pkgs, username, global_settings, ... }:
{
  services.upower.enable = true;

  home-manager.users.${username} = { config, ... }: {
    home.packages = [ pkgs.unstable.ashell ];
    xdg.configFile."ashell/config.toml".source =
      config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/dotfiles/ashell_config.toml";
  };
}
