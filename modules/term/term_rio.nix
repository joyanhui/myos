{
  pkgs,
  username,
  global_settings,
  ...
}:
let
  font = global_settings.font;
  backgroundColors = [
    "#0A181A"
    "#1A1025"
    "#101A2B"
    "#2A1414"
    "#122418"
    "#2A2110"
  ];
  rioConfig = background: ''
    [fonts]
    family = "${font.mono}"
    size = 18

    [window]
    opacity = 0.88

    [navigation]
    mode = "Tab"

    [colors]
    background = "${background}"

  '';
  rioConfigFiles = builtins.listToAttrs (
    [
      {
        name = "rio/config.toml";
        value.text = rioConfig (builtins.elemAt backgroundColors 0);
      }
    ]
    ++ builtins.genList (index: {
      name = "rio/config_${toString index}/config.toml";
      value.text = rioConfig (builtins.elemAt backgroundColors index);
    }) (builtins.length backgroundColors)
  );
  lastConfigIndex = builtins.length backgroundColors - 1;
  rioRandomBg = pkgs.writeShellScriptBin "rio-random-bg" ''
    set -eu

    configHome="''${XDG_CONFIG_HOME:-$HOME/.config}"
    configIndex="$(${pkgs.coreutils}/bin/shuf -i 0-${toString lastConfigIndex} -n 1)"
    rioConfigHome="$configHome/rio/config_$configIndex"

    if [ ! -r "$rioConfigHome/config.toml" ]; then
      printf '%s\n' "Rio configuration file not found: $rioConfigHome/config.toml" >&2
      exit 1
    fi

    export RIO_CONFIG_HOME="$rioConfigHome"
    exec ${pkgs.rio}/bin/rio "$@"
  '';
in
{
  home-manager.users.${username} = {
    home.packages = [
      pkgs.unstable.rio
      rioRandomBg
    ];

    xdg.configFile = rioConfigFiles;
  };
}
