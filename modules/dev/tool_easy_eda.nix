{
  pkgs,
  lib,
  username,
  global_settings,
  ...
}:
let
  pkgLocks = import ../pkg_locks_loader.nix { inherit pkgs lib global_settings; };

  lcedaPro = pkgs.stdenv.mkDerivation {
    pname = "lceda-pro";
    inherit (pkgLocks.getEntry "lceda-pro") version;
    src = pkgLocks.fetchSource "lceda-pro" "src";

    nativeBuildInputs = with pkgs; [
      unzip
      autoPatchelfHook
      makeWrapper
    ];

    buildInputs = with pkgs; [
      alsa-lib
      at-spi2-atk
      at-spi2-core
      atk
      cairo
      cups
      dbus
      expat
      gdk-pixbuf
      glib
      gtk3
      libgbm
      libx11
      libxcb
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxkbcommon
      libxrandr
      nspr
      nss
      pango
      udev
    ];

    unpackPhase = ''
      unzip -q $src || [ $? -eq 1 ]
      test -x lceda-pro/lceda-pro
    '';
    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;

    installPhase = ''
      mkdir -p $out/opt $out/bin $out/share/applications
      cp -r lceda-pro $out/opt/lceda-pro
      cp lceda-pro/lceda-pro.dkt $out/share/applications/lceda-pro.desktop
      sed -i "s|^Exec=.*|Exec=lceda-pro %f|; s|^Icon=.*|Icon=lceda-pro|" \
        $out/share/applications/lceda-pro.desktop
      for i in 16 24 32 48 64 96 128 256 512; do
        install -Dm644 lceda-pro/icon/icon_''${i}x''${i}.png \
          $out/share/icons/hicolor/''${i}x''${i}/apps/lceda-pro.png
      done
    '';

    preFixup = ''
      makeWrapper $out/opt/lceda-pro/lceda-pro $out/bin/lceda-pro \
        --add-flags "--no-sandbox --gtk-version=3"
    '';

    meta = {
      description = "嘉立创EDA专业版 (LCEDA Pro)";
      homepage = "https://lceda.cn/";
      license = lib.licenses.unfree;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      mainProgram = "lceda-pro";
    };
  };
in
{
  home-manager.users.${username}.home.packages = [ lcedaPro ];
}
