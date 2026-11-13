{
  pkgs,
  lib,
  username,
  global_settings,
  ...
}:
let
  pkgLocks = import ../pkg_locks_loader.nix { inherit pkgs lib global_settings; };

  PhotoGIMP = pkgs.stdenvNoCC.mkDerivation {
    pname = "PhotoGIMP";
    inherit (pkgLocks.entries.photo-gimp) version;

    src = pkgLocks.fetchSource "photo-gimp" "src";

    installPhase = ''
      mkdir -p $out/share/PhotoGIMP
      cp -r ./.config $out/share/PhotoGIMP
      cp -r ./.local $out/share/PhotoGIMP
      rm -rf $out/share/PhotoGIMP/.config/GIMP/3.0/gimprc  #这个文件在每次启动会被重新创建
      rm -rf $out/share/PhotoGIMP/.config/GIMP/3.0/pluginrc # 这个文件由 GIMP 启动后动态生成
    '';

    meta = {
      description = "PhotoGIMP";
      homepage = "https://github.com/Diolinux/PhotoGIMP";
      license = pkgs.lib.licenses.gpl3Only;
      platforms = pkgs.lib.platforms.all;
    };
  };
in
{
  home-manager = {
    users.${username} = {
      home.file = {
        ".config/GIMP/3.0" = {
          source = "${PhotoGIMP}/share/PhotoGIMP/.config/GIMP/3.0";
          recursive = true;
          onChange = ''
            chmod -R u+w ~/.config/GIMP/3.0
          '';
        };

        ".local/share/applications/org.gimp.GIMP.desktop" = {
          source = "${PhotoGIMP}/share/PhotoGIMP/.local/share/applications/org.gimp.GIMP.desktop";
        };

        ".local/share/icons/hicolor/16x16/apps/photogimp.png" = {
          source = "${PhotoGIMP}/share/PhotoGIMP/.local/share/icons/hicolor/16x16/apps/photogimp.png";
        };
        ".local/share/icons/hicolor/32x32/apps/photogimp.png" = {
          source = "${PhotoGIMP}/share/PhotoGIMP/.local/share/icons/hicolor/32x32/apps/photogimp.png";
        };
        ".local/share/icons/hicolor/48x48/apps/photogimp.png" = {
          source = "${PhotoGIMP}/share/PhotoGIMP/.local/share/icons/hicolor/48x48/apps/photogimp.png";
        };
        ".local/share/icons/hicolor/64x64/apps/photogimp.png" = {
          source = "${PhotoGIMP}/share/PhotoGIMP/.local/share/icons/hicolor/64x64/apps/photogimp.png";
        };
        ".local/share/icons/hicolor/128x128/apps/photogimp.png" = {
          source = "${PhotoGIMP}/share/PhotoGIMP/.local/share/icons/hicolor/128x128/apps/photogimp.png";
        };
        ".local/share/icons/hicolor/256x256/apps/photogimp.png" = {
          source = "${PhotoGIMP}/share/PhotoGIMP/.local/share/icons/hicolor/256x256/apps/photogimp.png";
        };
        ".local/share/icons/hicolor/512x512/apps/photogimp.png" = {
          source = "${PhotoGIMP}/share/PhotoGIMP/.local/share/icons/hicolor/512x512/apps/photogimp.png";
        };
      };

      home.packages = with pkgs; [
        gimp3
      ];
    };
  };
}
