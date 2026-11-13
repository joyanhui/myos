{ lib
, stdenv
, pkgs
, global_settings
, fetchurl
, dpkg
, wrapGAppsHook3
, autoPatchelfHook
, udev
, libdrm
, libpqxx
, unixODBC
, gst_all_1
, xorg
, libpulseaudio
,
}:

let
  pkgLocks = import ../../pkg_locks_loader.nix { inherit pkgs lib global_settings; };
in

stdenv.mkDerivation rec {
  pname = "freedownloadmanager";
  inherit (pkgLocks.entries.freedownloadmanager) version;

  src = pkgLocks.fetchSource pname "src";
  #curlOpts = "--proxy http://127.0.0.1:7890";

  unpackPhase = "dpkg-deb -x $src .";

  nativeBuildInputs = [
    dpkg
    wrapGAppsHook3
    autoPatchelfHook
  ];

  buildInputs = [
    libdrm
    libpqxx
    unixODBC
    stdenv.cc.cc
    pkgs.libtiff
    pkgs.wayland
    pkgs.libxkbcommon
    pkgs.krb5
    pkgs.xcb-util-cursor
  ]
  ++ (with gst_all_1; [
    gstreamer
    gst-libav
    gst-plugins-base
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
  ])
  ++ (with xorg; [
    xcbutilwm
    xcbutilimage
    xcbutilkeysyms
    xcbutilrenderutil
    libpulseaudio
  ]);

  runtimeDependencies = [
    (lib.getLib udev)
  ];

  autoPatchelfIgnoreMissingDeps = [
    "libmysqlclient.so.21"
    "libclntsh.so.23.1"
    "libfbclient.so.2"
    "libmimerapi.so"
  ];

  postFixup = ''
    for plugin in $out/freedownloadmanager/plugins/sqldrivers/libqsqlmysql.so \
                  $out/freedownloadmanager/plugins/sqldrivers/libqsqloci.so \
                  $out/freedownloadmanager/plugins/sqldrivers/libqsqlibase.so \
                  $out/freedownloadmanager/plugins/sqldrivers/libqsqlmimer.so; do
      if [ -e "$plugin" ]; then
        rm "$plugin"
      fi
    done
    for lib in $out/freedownloadmanager/plugins/imageformats/libqtiff.so; do
      if [ -e "$lib" ]; then
        patchelf --replace-needed libtiff.so.5 libtiff.so.6 "$lib"
      fi
    done
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp -r opt/freedownloadmanager $out
    cp -r usr/share $out
    ln -s $out/freedownloadmanager/fdm $out/bin/${pname}

    substituteInPlace $out/share/applications/freedownloadmanager.desktop \
      --replace 'Exec=/opt/freedownloadmanager/fdm' 'Exec=${pname}' \
      --replace "Icon=/opt/freedownloadmanager/icon.png" "Icon=$out/freedownloadmanager/icon.png"
  '';

  meta = with lib; {
    description = "A smart and fast internet download manager";
    homepage = "https://www.freedownloadmanager.org";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [ ];
  };
}
