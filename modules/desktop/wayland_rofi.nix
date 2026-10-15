{
  pkgs,
  username,
  global_settings,
  ...
}:
let
  rofiConfig = builtins.replaceStrings [ "__ICON_THEME__" ] [ global_settings.theme.iconTheme ] (
    builtins.readFile ./rofi_config.rasi
  );
in
{
  environment.systemPackages = with pkgs; [
    rofi
  ];

  home-manager.users.${username} = {
    xdg.configFile."rofi/config.rasi".text = rofiConfig;
  };
}
