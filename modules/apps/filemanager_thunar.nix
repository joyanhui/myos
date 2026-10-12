{ pkgs
, username
, ...
}:

{
  home-manager = {
    users.${username} = {
      home.packages = with pkgs; [
        thunar

        thunar-volman
        thunar-archive-plugin
        thunar-media-tags-plugin
        thunar-dropbox-plugin
        thunar-shares-plugin

        gvfs
        sshfs-fuse

        ffmpegthumbnailer
        poppler-utils
        libgsf

        lazygit
      ];

      xdg.configFile."Thunar/thunarrc" = {
        force = true;
        text = ''
          [Configuration]
          LastViewStyle=ThunarDetailsView
          LastMenubarVisibility=TRUE
          LastToolbarVisibility=TRUE
          LastStatusbarVisibility=TRUE
          LastShowThumbnails=TRUE
          LastShowHidden=FALSE
          MiscShowFullPath=FALSE
          MiscShowTooltips=TRUE
          ShortcutsIconSize=ICON_SIZE_SMALL
          LastLocationBar=ThunarLocationBar
          LastSidePane=ThunarShortcutsPane
          LastView=ThunarIconView
          LastZoomLevel=THUNAR_ZOOM_LEVEL_100_PERCENT
          LastSeparatorPosition=170
          LastWindowWidth=900
          LastWindowHeight=600
          LastSortColumn=name
          LastSortOrder=GTK_SORT_ASCENDING
          LastToolbarItems=0,1,2,3,4,5,6,7,8,9,10
          LastTerminalEmulator=rio
        '';
      };

      xdg.configFile."Thunar/uca.xml" = {
        force = true;
        text = ''
          <?xml version="1.0" encoding="UTF-8"?>
          <actions>
            <action>
              <icon>utilities-terminal</icon>
              <name>在终端中打开</name>
              <submenu></submenu>
              <unique-id>1709123456</unique-id>
              <command>rio -w %f</command>
              <description>在 Rio 终端中打开当前目录</description>
              <patterns>*</patterns>
              <startup-notify/>
              <directories/>
            </action>
            <action>
              <icon>git</icon>
              <name>Lazygit</name>
              <submenu></submenu>
              <unique-id>1709123457</unique-id>
              <command>rio -w %f -e lazygit</command>
              <description>在 Lazygit 中打开当前 Git 仓库</description>
              <patterns>*</patterns>
              <startup-notify/>
              <directories/>
            </action>
          </actions>
        '';
      };
    };
  };
}
