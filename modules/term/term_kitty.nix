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
      home.packages = with pkgs; [ kitty ];

      xdg.configFile."kitty/kitty.conf".text = ''
        font_family ${font.mono}
        font_size ${toString font.size.term}

        theme Wez

        term xterm-256color

        shell fish

        tab_fade 1 1 1
        tab_title_template {fmt.fg.red}{bell_symbol}{activity_symbol}{fmt.fg.tab}{index}:{title}

        modify_font underline_position +3
        modify_font underline_thickness 150%

        allow_remote_control yes
        listen_on unix:@mykitty

        background_opacity 0.88
        background #0A181A

        cursor_shape beam
        cursor_blink_interval 0.5

        map ctrl+d launch --location=hsplit
        map ctrl+r launch --location=vsplit
        map ctrl+alt+w close_window

        map ctrl+j kitten pass_keys.py neighboring_window bottom ctrl+j
        map ctrl+k kitten pass_keys.py neighboring_window top    ctrl+k
        map ctrl+h kitten pass_keys.py neighboring_window left   ctrl+h
        map ctrl+l kitten pass_keys.py neighboring_window right  ctrl+l

        map alt+j kitten pass_keys.py relative_resize down  3 alt+j
        map alt+k kitten pass_keys.py relative_resize up    3 alt+k
        map alt+h kitten pass_keys.py relative_resize left  3 alt+h
        map alt+l kitten pass_keys.py relative_resize right 3 alt+l

        enabled_layouts splits:split_axis=horizontal
      '';
    };
  };
}
