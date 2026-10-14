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
  home-manager = {
    users.${username} = {
      home.packages = with pkgs; [ rio ];

      xdg.configFile."rio/config.toml".text = ''
        [window]
        opacity = 0.88
        blur = true

        [colors]
        background = '#0A181A'

        [shell]
        program = "fish"

        [cursor]
        shape = "beam"

        [fonts]
        family = "${font.mono}"
        size = ${toString font.size.term}
      '';
    };
  };
}
