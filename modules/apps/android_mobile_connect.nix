{
  pkgs,
  username,
  ...
}:
let
  myPyScrcpy = pkgs.writeShellScriptBin "myPyScrcpy" ''
    exec ${
      pkgs.python3.withPackages (ps: [ ps.tkinter ])
    }/bin/python3 ${./../../script/myPyScrcpy.py} "$@"
  '';
in
{
  programs.kdeconnect = {
    enable = true;
    package = pkgs.kdePackages.kdeconnect-kde;
  };

  users.groups.adbusers = { };
  users.users.${username}.extraGroups = [ "adbusers" ];

  home-manager.users.${username} =
    { config, ... }:
    {
      home.packages = with pkgs; [
        qtscrcpy
        scrcpy
        android-tools
        myPyScrcpy
      ];

      xdg.desktopEntries."QtScrcpy" = {
        name = "QtScrcpy";
        genericName = "Android Display Control";
        exec = "env QT_QPA_PLATFORM=\"wayland;xcb\" QtScrcpy %U";
        icon = "qtscrcpy";
        categories = [
          "Utility"
          "RemoteAccess"
        ];
        terminal = false;
        type = "Application";
      };

      xdg.desktopEntries."myPyScrcpy" = {
        name = "myPyScrcpy";
        genericName = "Android Display Control";
        exec = "myPyScrcpy";
        icon = "scrcpy";
        categories = [
          "Utility"
          "RemoteAccess"
        ];
        terminal = false;
        type = "Application";
      };
    };
}
