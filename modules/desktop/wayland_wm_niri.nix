{
  pkgs,
  lib,
  username,
  global_settings,
  ...
}:
let
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
    { config, ... }:
    {
      xdg.configFile = {
        "niri/config.kdl".source =
          config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/modules/desktop/niri_config.kdl";
      };
    };
}