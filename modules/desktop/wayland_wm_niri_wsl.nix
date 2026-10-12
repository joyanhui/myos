{
  config,
  pkgs,
  lib,
  username,
  global_settings,
  ...
}:
let
  sessionVars = config.environment.sessionVariables;

  niriGpu = pkgs.symlinkJoin {
    name = "niri-gpu";
    paths = [ pkgs.niri ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/niri \
        --set-default GALLIUM_DRIVER "${sessionVars.GALLIUM_DRIVER}" \
        --set-default MESA_LOADER_DRIVER_OVERRIDE "${sessionVars.MESA_LOADER_DRIVER_OVERRIDE}" \
        --prefix LD_LIBRARY_PATH : "${sessionVars.LD_LIBRARY_PATH}"
    '';
  };

  invisibleCursorTheme = pkgs.runCommand "niri-invisible-cursor-theme" {
    nativeBuildInputs = [
      pkgs.xcursorgen
      pkgs.python3
    ];
  } ''
    set -eu
    theme=$out/share/icons/niri-invisible
    mkdir -p $theme/cursors
    printf '[Icon Theme]\nName=niri-invisible\n' > $theme/index.theme
    python3 - <<'PYEOF'
    import struct, zlib

    def chunk(kind, data):
        return (
            struct.pack(">I", len(data))
            + kind
            + data
            + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
        )

    size = 32
    raw = b"".join(b"\x00" + b"\x00\x00\x00\x00" * size for _ in range(size))
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw))
        + chunk(b"IEND", b"")
    )
    open("cursor.png", "wb").write(png)
    PYEOF
    printf '32 1 1 cursor.png\n' > cursor.cfg
    for name in default left_ptr; do
      xcursorgen cursor.cfg "$theme/cursors/$name"
    done
  '';

  niriPackage = pkgs.symlinkJoin {
    name = "niri-wrapped";
    paths = [ niriGpu ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/niri --prefix LD_LIBRARY_PATH : "${
        pkgs.lib.makeLibraryPath (with pkgs; [
          libx11
          libxcursor
          libxi
          libxrandr
          libxinerama
          libxext
          libxrender
          libxtst
        ])
      }"
    '';
  };
in
{
  environment.systemPackages = with pkgs; [
    niriPackage
    invisibleCursorTheme
  ];

  services.power-profiles-daemon.enable = lib.mkForce false;
  hardware.i2c.enable = lib.mkForce false;

  home-manager.users.${username} =
    { config, ... }:
    {
      xdg.configFile = {
        "niri/config.kdl".source =
          config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/modules/desktop/niri_wsl_config.kdl";
        "rofi/config.rasi".source =
          config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/modules/desktop/rofi_config.rasi";
      };
    };
}