{
  pkgs,
  username,
  global_settings,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    rofi
  ];

  home-manager.users.${username} =
    { config, ... }:
    {
      xdg.configFile."rofi/config.rasi".source =
        config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/modules/desktop/rofi_config.rasi";
    };
}
