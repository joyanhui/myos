{ username, global_settings, ... }:
{
  home-manager.users.${username} = { config, ... }: {
    home.file.".local/bin/bar-lunar".source =
      config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/script/bar_lunar.py";
    home.file.".local/bin/bar-weather".source =
      config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/script/bar_weather.py";
  };
}
