{
  username,
  ...
}:
let
  run_py_icon = ../../static_file/icons/python.png;
  repoRoot = "${toString ../../.}";
in
{
  home-manager = {
    users.${username} = {

      home.file = {
        /*
            ".local/share/applications/zed_aio.AppImage.desktop".text = ''
              [Desktop Entry]
              Name=zed_aio
              Exec=/home/nixos/myworkspace/my-opt/zed-x86_64.AppImage /home/nixos/myworkspace/syx_lot_manager_aio
              Icon=/home/nixos/myworkspace/my-opt/z2.png
              Terminal=false
              Type=Application
              Categories=Development;IDE;
              Version=1.0
              StartupNotify=true
              StartupWMClass=Code
              MimeType=text/plain;
            '';

            ".local/share/applications/zed_adguardhomeQQ_rules.AppImage.desktop".text = ''
              [Desktop Entry]
              Name=zed_adguardhome_rules
              Exec=/home/nixos/myworkspace/my-opt/zed-x86_64.AppImage /home/nixos/myworkspace/adguardhome-rules
              Icon=/home/nixos/myworkspace/my-opt/z2.png
              Terminal=false
              Type=Application
              Categories=Development;IDE;
              Version=1.0
              StartupNotify=true
              StartupWMClass=Code
              MimeType=text/plain;
            '';

            ".local/share/applications/zed_nixos.AppImage.desktop".text = ''
              [Desktop Entry]
              Name=zed_nixos_joyanhui
              Exec=/home/nixos/myworkspace/my-opt/zed-x86_64.AppImage ${repoRoot}
              Icon=/home/nixos/myworkspace/my-opt/z2.png
              Terminal=false
              Type=Application
              Categories=Development;IDE;
              Version=1.0
              StartupNotify=true
              StartupWMClass=Code
              MimeType=text/plain;
            '';

          ".local/share/applications/webapp.tv.desktop".text = ''
            [Desktop Entry]
            Name=tv.movie.lyh
            Comment=webapp tv.movie.lyh
            Exec=/home/nixos/.local/share/flatpak/exports/bin/org.chromium.Chromium --app=https://tv.leiyanhui.com
            Icon=/home/nixos/myworkspace/my-opt/mov.png
            Terminal=false
            Type=Application
            Categories=Network;AudioVideo;
            Version=1.0
            StartupNotify=true
            StartupWMClass=org.chromium.Chromium
          '';
          ".local/share/applications/webapp.gmail.desktop".text = ''
            [Desktop Entry]
            Name=Gmail
            Comment=webapp Gmail
            Exec=/home/nixos/.local/share/flatpak/exports/bin/org.chromium.Chromium --app=https://mail.google.com
            Icon=/home/nixos/myworkspace/my-opt/gmail.png
            Terminal=false
            Type=Application
            Categories=Network;
            Version=1.0
            StartupNotify=true
            StartupWMClass=org.chromium.Chromium
          '';

          ".local/share/applications/webapp.note.desktop".text = ''
            [Desktop Entry]
            Name=note
            Comment=webapp note
            Exec=/home/nixos/.local/share/flatpak/exports/bin/org.chromium.Chromium --app=https://note.jia.leiyanhui.com:50443
            Icon=/home/nixos/myworkspace/my-opt/notepad.png
            Terminal=false
            Type=Application
            Categories=Network;
            Version=1.0
            StartupNotify=true
            StartupWMClass=org.chromium.Chromium
          '';

          ".local/share/applications/webapp.music163.desktop".text = ''
            [Desktop Entry]
            Name=music163
            Comment=webapp music163
            Exec=/home/nixos/.local/share/flatpak/exports/bin/org.chromium.Chromium --app=https://music.163.com/#/my/
            Icon=/home/nixos/myworkspace/my-opt/music-163com-200.png
            Terminal=false
            Type=Application
            Categories=Network;AudioVideo;
            Version=1.0
            StartupNotify=true
            StartupWMClass=org.chromium.Chromiumde
          '';
        */
      };
    };
  };
}
