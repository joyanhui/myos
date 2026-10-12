{
  pkgs,
  username,
  ...
}:
let
  version = "4.1.0.13";
  srcOfficial = pkgs.fetchurl {
    # nix-prefetch-url https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage | xargs -I{} nix hash convert --hash-algo sha256 --to sri {}
    url = "https://dldir1v6.qq.com/weixin/Universal/Linux/WeChatLinux_x86_64.AppImage";
    hash = "sha256-RSYYC8qYASh5FZmvEi/0eVACpXFaUQ9qZUgOK+aHQkQ=";
  };

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
