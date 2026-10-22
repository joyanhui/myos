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
     obs-studio
                ];
      };
  };
}
