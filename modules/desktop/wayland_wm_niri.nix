{
  pkgs,
  lib,
  username,
  global_settings,
  ...
}:
let
  niriConfig = builtins.replaceStrings
    [ "__CURSOR_THEME__" ]
    [ global_settings.theme.cursorTheme ]
    (builtins.readFile ./niri_config.kdl);
  niriPackage = pkgs.symlinkJoin {
    name = "niri-wrapped";
    paths = [ pkgs.niri ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/niri --prefix LD_LIBRARY_PATH : "${
        pkgs.lib.makeLibraryPath (with pkgs; [
          libx11
          libxcursor
          libxi
          libxrandr
          libxinerama
          libxext
          libxrender
          libxtst
        ])
      }"
    '';
  };
in
{
  environment.systemPackages = with pkgs; [
    niriPackage
  ];

  home-manager.users.${username} =
    { ... }:
    {
      xdg.configFile."niri/config.kdl".text = niriConfig;
    };
}