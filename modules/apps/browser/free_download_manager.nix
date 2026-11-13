{ pkgs
, lib
, username
, global_settings
, ...
}:

let
  freedownloadmanager = import ./free_download_manager_pkg.nix {
    inherit pkgs lib global_settings;
    inherit (pkgs)
      stdenv
      fetchurl
      dpkg
      wrapGAppsHook3
      autoPatchelfHook
      udev
      libdrm
      libpqxx
      unixODBC
      gst_all_1
      xorg
      libpulseaudio
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
