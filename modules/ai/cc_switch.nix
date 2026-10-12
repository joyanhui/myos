{
  pkgs,
  lib,
  username,
  global_settings,
  ...
}:
let
  ghProxy = global_settings.ghProxy;
  cc_switch =
    with pkgs;
    stdenv.mkDerivation rec {
      pname = "cc-switch";
      version = "3.20.0";

      src = fetchurl {
        url = "${ghProxy}/https://github.com/farion1231/cc-switch/releases/download/v${version}/CC-Switch-v${version}-Linux-x86_64.deb";
        hash = "sha256-1AruLIblKXgTXBX986fLn5VVrXwEatO+LcrF7c0qUsA=";
      };

      nativeBuildInputs = [
        autoPatchelfHook
        dpkg
        makeWrapper
        wrapGAppsHook3
      ];

      buildInputs = [
        alsa-lib
        atk
        at-spi2-atk
        cairo
        dbus
        expat
        fontconfig
        gdk-pixbuf
        glib
        gsettings-desktop-schemas
        gst_all_1.gst-plugins-base
        gst_all_1.gstreamer
        gtk3
        libayatana-appindicator
        libdrm
        libgbm
        libGL
        libsoup_3
        libsecret
        libxkbcommon
        nss
        pango
        stdenv.cc.cc
        webkitgtk_4_1
        libx11
        libxcomposite
        libxdamage
        libxext
        libxfixes
        libxrandr
      ];

      unpackPhase = ''
        runHook preUnpack
        dpkg-deb -x "$src" .
        runHook postUnpack
      '';

      installPhase = ''
        runHook preInstall

        mkdir -p "$out/bin" "$out/lib/cc-switch" "$out/share"

        cp -r usr/share/* "$out/share/"
        cp usr/bin/cc-switch "$out/lib/cc-switch/cc-switch"

        makeWrapper "$out/lib/cc-switch/cc-switch" "$out/bin/cc-switch" \
          --argv0 cc-switch \
          --set-default WEBKIT_DISABLE_COMPOSITING_MODE 1 \
          --set-default ELECTRON_OZONE_PLATFORM_HINT auto \
          --set-default GDK_BACKEND 'wayland,x11,*' \
          --set-default PATH "${lib.makeBinPath [ xdg-utils ]}"

        runHook postInstall
      '';

      preFixup = ''
        gappsWrapperArgs+=(
          --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}"
        )
      '';

      passthru.updateScript = nix-update-script { };

      meta = with lib; {
        description = "CC Switch desktop app for managing AI coding providers";
        homepage = "https://github.com/farion1231/cc-switch";
        license = licenses.unfree;
        sourceProvenance = with sourceTypes; [ binaryNativeCode ];
        mainProgram = "cc-switch";
        platforms = [ "x86_64-linux" ];
      };
    };
in
{
  home-manager.users.${username} = {
    home.packages = [ cc_switch ];
  };
}
