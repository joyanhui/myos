{
  pkgs,
  username,
  global_settings,
  ...
}:
{
  home-manager = {
    users.${username} =
      { config, ... }:
      {
        home.packages = with pkgs; [
          helix
          #helix-gpt
        ];
        xdg.configFile = {
          "helix/config.toml".source =
            config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/dotfiles/helix_config.toml";
          "helix/languages.toml".source =
            config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/dotfiles/helix_languages.toml";
        };
      };
  };
}
