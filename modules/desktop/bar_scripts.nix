{ pkgs, username, global_settings, ... }:
{
  home-manager.users.${username} = { config, ... }: {
    home.packages = [ pkgs.smartmontools ];
    home.file.".local/bin/bar-lunar".source =
      config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/script/bar_lunar.py";
    home.file.".local/bin/bar-weather".source =
      config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/script/bar_weather.py";
    home.file.".local/bin/bar-power".source =
      config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/script/bar_power_status.py";
    home.file.".local/bin/bar-disk".source =
      config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/script/bar_disk.py";
  };
}
