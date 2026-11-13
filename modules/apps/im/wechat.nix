{
  pkgs,
  lib,
  username,
  global_settings,
  ...
}:
let
  pkgLocks = import ../../pkg_locks_loader.nix { inherit pkgs lib global_settings; };
  version = pkgLocks.entries.wechat.version;
  srcOfficial = pkgLocks.fetchSource "wechat" "src";

  appimageContents = pkgs.appimageTools.extract {
    pname = "wechat";
    inherit version;
    src = srcOfficial;
    postExtract = ''
      patchelf --replace-needed libtiff.so.5 libtiff.so $out/opt/wechat/wechat
    '';
  };

  wechatOfficial = pkgs.appimageTools.wrapAppImage {
    pname = "wechat";
    inherit version;
    src = appimageContents;
    meta = pkgs.wechat.meta;
    extraInstallCommands = ''
      mkdir -p $out/share/applications
      cp ${appimageContents}/wechat.desktop $out/share/applications/
      mkdir -p $out/share/icons/hicolor/256x256/apps
      cp ${appimageContents}/wechat.png $out/share/icons/hicolor/256x256/apps/
      substituteInPlace $out/share/applications/wechat.desktop --replace-fail AppRun wechat
    '';
  };
in
{
  home-manager = {
    users.${username} = {
      home.packages = with pkgs; [
        wechatOfficial
        #wechat-uos
      ];

      xdg.desktopEntries."wechat" = {
        exec = "env QT_IM_MODULE=fcitx wechat %U";
        name = "wechat";
        type = "Application";
        categories = [ "Utility" ];
        terminal = false;
        startupNotify = true;
        icon = "wechat";
      };
    };
  };
}
