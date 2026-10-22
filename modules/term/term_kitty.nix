{
  pkgs,
  username,
  global_settings,
  ...
}:
let
  kittyHelp = pkgs.writeShellScriptBin "kitty-help" ''
    cat <<'EOF'
    Kitty 快捷键（默认及当前配置）

    Ctrl+Shift+Enter  新建分屏窗
    Ctrl+Shift+W      关闭分屏窗
    Ctrl+Shift+T      新建标签页
    Ctrl+Shift+Right  下一个标签页
    Ctrl+Shift+Left   上一个标签页
    Ctrl+D            当前配置：新建水平分屏
    Ctrl+R            当前配置：新建垂直分屏
    Ctrl+Alt+W        当前配置：关闭窗口
    EOF
  '';
  font = global_settings.font;
  backgroundColors = [
    "#0A181A"
    "#1A1025"
    "#101A2B"
    "#2A1414"
    "#122418"
    "#2A2110"
  ];
  kittyConfig = background: ''
    font_family ${font.mono}
    font_size ${toString font.size.term}

    theme Wez

    term xterm-256color

    shell zsh

    tab_fade 1 1 1
    tab_title_template {fmt.fg.red}{bell_symbol}{activity_symbol}{fmt.fg.tab}{index}:{title}

    modify_font underline_position +3
    modify_font underline_thickness 150%

    allow_remote_control yes
    listen_on unix:@mykitty

    background_opacity 0.88
    background ${background}

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
  kittyConfigFiles = builtins.listToAttrs (
    [
      {
        name = "kitty/kitty.conf";
        value.text = kittyConfig (builtins.elemAt backgroundColors 0);
      }
    ]
    ++ builtins.genList (index: {
      name = "kitty/kitty_${toString index}.conf";
      value.text = kittyConfig (builtins.elemAt backgroundColors index);
    }) (builtins.length backgroundColors)
  );
  lastConfigIndex = builtins.length backgroundColors - 1;
  kittyRandomBg = pkgs.writeShellScriptBin "kitty-random-bg" ''
    set -eu

    configHome="''${XDG_CONFIG_HOME:-$HOME/.config}"
    configIndex="$(${pkgs.coreutils}/bin/shuf -i 0-${toString lastConfigIndex} -n 1)"
    configFile="$configHome/kitty/kitty_$configIndex.conf"

    if [ ! -r "$configFile" ]; then
      printf '%s\n' "Kitty configuration file not found: $configFile" >&2
      exit 1
    fi

    exec ${pkgs.kitty}/bin/kitty --config "$configFile" "$@"
  '';
in
{
  home-manager = {
    users.${username} = {
      home.packages = [
        pkgs.kitty
        kittyRandomBg
        kittyHelp
      ];

      xdg.configFile = kittyConfigFiles;
    };
  };
}
