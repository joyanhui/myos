{ pkgs
, username
, ...
}:

let
  freedownloadmanager = import ./free_download_manager_pkg.nix {
    inherit (pkgs)
      lib
      stdenv
      fetchurl
      dpkg
      wrapGAppsHook
      autoPatchelfHook
      udev
      libdrm
      libpqxx
      unixODBC
      gst_all_1
      xorg
      libpulseaudio
      mysql80
      ;
  };
in
{
  # https://github.com/kreutzi/nix-FDM
  home-manager = {
    users.${username} = {
      home.packages = [
        freedownloadmanager
      ];
    };
  };
}
