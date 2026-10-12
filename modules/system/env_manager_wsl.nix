{ lib, pkgs, ... }:
{
  config.envManager.extraVars = {
    MESA_LOADER_DRIVER_OVERRIDE = "d3d12";
    GALLIUM_DRIVER = "d3d12";
    LD_LIBRARY_PATH =
      lib.makeLibraryPath (
        with pkgs;
        [
          libXcursor
          libXrandr
          libXi
          libXext
          openssl
          stdenv.cc.cc.lib
        ]
      )
      + ":/usr/lib/wsl/lib";
  };
}