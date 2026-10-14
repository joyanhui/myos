{
  pkgs,
  username,
  global_settings,
  ...
}:
let
  font = global_settings.font;
in
{
  home-manager.users.${username} = {
    home.packages = with pkgs; [ ghostty ];

    xdg.configFile."ghostty/config".text = ''
      background = #0A181A
      background-opacity = 0.88
      background-blur = true
      command = fish
      cursor-style = bar
      font-family = "Sarasa Fixed SC"
      font-size = ${toString font.size.term}

    '';
  };
}
