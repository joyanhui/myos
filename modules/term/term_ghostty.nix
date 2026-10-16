{
  pkgs,
  username,
  global_settings,
  ...
}:
let
  readme = ''
    在默认的config之外另外创建多个config文件用来启动不同颜色的ghostty
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
  ghosttyConfig = background: ''
    background = ${background}
    background-opacity = 0.88
    background-blur = true
    command = zsh
    cursor-style = bar
    font-family = "Sarasa Fixed SC"
    font-size = ${toString font.size.term}

  '';
  ghosttyConfigFiles = builtins.listToAttrs (
    [
      {
        name = "ghostty/config";
        value.text = ghosttyConfig (builtins.elemAt backgroundColors 0);
      }
    ]
    ++ builtins.genList (
      index:
      {
        name = "ghostty/config_${toString index}";
        value.text = ghosttyConfig (builtins.elemAt backgroundColors index);
      }
    ) (builtins.length backgroundColors)
  );
  lastConfigIndex = builtins.length backgroundColors - 1;
  ghosttyRandomBg = pkgs.writeShellScriptBin "ghostty-random-bg" ''
    set -eu

    configHome="''${XDG_CONFIG_HOME:-$HOME/.config}"
    configIndex="$(${pkgs.coreutils}/bin/shuf -i 0-${toString lastConfigIndex} -n 1)"
    configFile="$configHome/ghostty/config_$configIndex"

    if [ ! -r "$configFile" ]; then
      printf '%s\n' "Ghostty configuration file not found: $configFile" >&2
      exit 1
    fi

    exec ${pkgs.ghostty}/bin/ghostty --config-file="$configFile" "$@"
  '';
in
{
  home-manager.users.${username} = {
    home.packages = [
      pkgs.ghostty
      ghosttyRandomBg
    ];

    xdg.configFile = ghosttyConfigFiles // {
      "ghostty/nix.readme.md".text = readme;
    };
  };
}
