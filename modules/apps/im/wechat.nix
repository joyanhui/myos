{
  pkgs,
  username,
  ...
}:
{
  home-manager = {
    users.${username} = {
      home.packages = with pkgs; [
        wechat
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
