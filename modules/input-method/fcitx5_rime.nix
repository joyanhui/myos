{
  pkgs,
  lib,
  config,
  username,
  global_settings,
  hmStandalone ? false,
  ...
}:

let
  fcitx5BinPkg = if hmStandalone then pkgs.fcitx5 else config.i18n.inputMethod.package;
  fcitx5Bin = "${fcitx5BinPkg}/bin/fcitx5";
  fcitx5ThemesDir = "${fcitx5BinPkg}/share/fcitx5/themes";

  fcitx5WantedBy =
    if hmStandalone then
      [ "graphical-session.target" ]
    else
      [ ];

  fcitx5Wrapper = pkgs.writeShellScriptBin "fcitx5" ''
    if [ -n "''${NIRI_SOCKET:-}" ] && [ -S "''${NIRI_SOCKET}" ]; then
      exec ${fcitx5Bin} "$@"
    elif [ -d /mnt/wslg ]; then
      for _i in $(seq 1 50); do
        [ -S /tmp/.X11-unix/X0 ] && break
        sleep 0.1
      done
      export DISPLAY="''${DISPLAY:-:0}"
      exec ${fcitx5Bin} --disable=waylandim "$@"
    else
      exec ${fcitx5Bin} "$@"
    fi
  '';

  fcitx5Path = pkgs.symlinkJoin {
    name = "fcitx5-input-method";
    paths = [ fcitx5BinPkg ];
    postBuild = ''
      rm -f $out/bin/fcitx5
      ln -s ${fcitx5Wrapper}/bin/fcitx5 $out/bin/fcitx5
    '';
  };

  fcitx5Service = {
    Unit = {
      Description = "Fcitx5 Input Method";
      After = [ "dbus.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "dbus";
      BusName = "org.fcitx.Fcitx5";
      ExecStart = "${fcitx5Wrapper}/bin/fcitx5";
      Restart = "on-failure";
      RestartSec = 2;
    };
  }
  // lib.optionalAttrs (fcitx5WantedBy != [ ]) {
    Install = {
      WantedBy = fcitx5WantedBy;
    };
  };
  rime-ice = pkgs.stdenvNoCC.mkDerivation {
    pname = "rime-ice";
    version = "2026.06.30";

    /*
      src = pkgs.fetchFromGitHub {
        owner = "iDvel";
        repo = "rime-ice";
        rev = "2024.12.12";
        hash = "sha256-2QZdlLGZwWIesbjYTE/2yhM1hHGVVp7jR02bR0oqxV0=";
      };
    */

    src = pkgs.fetchzip {
      url = "${global_settings.ghProxy}/https://github.com/iDvel/rime-ice/archive/refs/tags/2026.06.30.tar.gz";
      hash = "sha256-HReBFYih39ohqZ2UAX6wPjjh0KuIauJPSOjk6ZXidss=";
    };

    installPhase = ''
      mkdir -p $out/share/rime-data
      rm -rf ./others
      rm -f README.md LICENSE
      rm -rf ./.github
      rm squirrel.yaml weasel.yaml
      rm default.yaml custom_phrase.txt
      cp -r ./* $out/share/rime-data
    '';

    meta = {
      description = "Rime 配置：雾凇拼音 | 长期维护的简体词库";
      homepage = "https://github.com/iDvel/rime-ice";
      license = pkgs.lib.licenses.gpl3Only;
      platforms = pkgs.lib.platforms.all;
    };
  };

  commonXdg = {
    xdg.configFile = {
      "fcitx5/conf/chttrans.conf" = {
        force = true;
        text = ''
          [Global]
          Engine=OpenCC
          OpenCCS2TProfile=default
          OpenCCT2SProfile=default

          [Hotkey]
          0=ControlL+Shift+Alt+L
        '';
      };

      "fcitx5/conf/classicui.conf" = {
        force = true;
        text = ''
          Theme=catppuccin-mocha-mauve
          DarkTheme=catppuccin-mocha-mauve
          Font=${global_settings.font.mono} ${toString global_settings.font.size.xxlarge}
        '';
      };
    };

    xdg.dataFile = {
      "fcitx5/themes/catppuccin-mocha-mauve".source = "${fcitx5ThemesDir}/catppuccin-mocha-mauve";

      "dbus-1/services/org.fcitx.Fcitx5.service" = {
        force = true;
        text = ''
          [D-BUS Service]
          Name=org.fcitx.Fcitx5
          Exec=${fcitx5Wrapper}/bin/fcitx5
          SystemdService=fcitx5.service
        '';
      };
    };
  };

  rimeHomeFile = config: {
    ".local/share/fcitx5/rime" = {
      source = "${rime-ice}/share/rime-data";
      recursive = true;
      onChange = ''
        mkdir -p ~/.local/share/fcitx5/rime
        chmod -R u+w ~/.local/share/fcitx5/rime
        rm -f ~/.local/share/fcitx5/rime/*.bin
        rm -f ~/.local/share/fcitx5/rime/build/*
      '';
    };

    ".local/share/fcitx5/rime/default.yaml".source = config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/modules/input-method/rime_default.yaml";

    ".local/share/fcitx5/rime/custom_phrase.txt".source = config.lib.file.mkOutOfStoreSymlink "${global_settings.secretsDir}/fcitx5_rime_custom_phrase.txt";
  };
in
if hmStandalone then
  {
    home.packages =
      (with pkgs; [
        fcitx5-rime
        qt6Packages.fcitx5-configtool
        fcitx5-gtk
        libsForQt5.fcitx5-qt
        kdePackages.fcitx5-qt
        fcitx5-lua
        catppuccin-fcitx5
        librime-lua
      ])
      ++ [ fcitx5Path ];

    xdg = commonXdg.xdg;

    home.file = rimeHomeFile config;

    systemd.user.services.fcitx5 = fcitx5Service;
  }
else
  {
    home-manager.users.${username} = { config, lib, pkgs, ... }: {
      home.packages = [ fcitx5Path ];

      systemd.user.services.fcitx5 = fcitx5Service;

      inherit (commonXdg) xdg;
      home.file = rimeHomeFile config;
    };

    i18n = {
      inputMethod = {
        type = "fcitx5";
        enable = true;
        package = lib.mkForce (pkgs.qt6Packages.fcitx5-with-addons.override {
          inherit (config.i18n.inputMethod.fcitx5) addons;
          withConfigtool = true;
        });
        fcitx5 = {
          waylandFrontend = true;
          addons =
            (with pkgs; [
              fcitx5-gtk
              libsForQt5.fcitx5-qt
              kdePackages.fcitx5-qt
              fcitx5-lua
              catppuccin-fcitx5
              librime-lua
              fcitx5-rime
              rime-ice
              pkgs.qt6Packages.fcitx5-configtool
            ]);
          settings = {
            globalOptions = {
              Behavior = {
                AutoSavePeriod = 0;
              };
            };
            addons = {
              classicui.globalSection = {
                Theme = "catppuccin-mocha-mauve";
                DarkTheme = "catppuccin-mocha-mauve";
                Font = "${global_settings.font.mono} ${toString global_settings.font.size.xxlarge}";
              };
            };
            inputMethod = {
              "Groups/0" = {
                Name = "Default";
                "Default Layout" = "us";
                DefaultIM = "rime";
              };
              "Groups/0/Items/0" = {
                Name = "rime";
              };
              GroupOrder = {
                "0" = "Default";
              };
            };
          };
        };
      };
    };
  }