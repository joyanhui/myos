{
  pkgs,
  global_settings,
  username,
  hmStandalone ? false,
  smallFonts ? false,
  ...
}:
let
  vistaFontsChs = pkgs.vista-fonts-chs.overrideAttrs (old: {
    src = pkgs.fetchurl {
      url = "${global_settings.helloProxy}/https://web.archive.org/web/20161221192937if_/http://download.microsoft.com/download/d/6/e/d6e2ff26-5821-4f35-a18b-78c963b1535d/VistaFont_CHS.EXE";
      hash = "sha256-saMIBEDTt9Ijv8g1nQHRNTG1ykIbHrCxjzdhhRYYleM=";
    };
  });

  jetbrainsMonoNerdFont = pkgs.nerd-fonts.jetbrains-mono.overrideAttrs (old: {
    src = old.src.overrideAttrs (o: {
      urls = map (u: "${global_settings.ghProxy}/${u}") o.urls;
    });
  });

  sfMono = pkgs.stdenvNoCC.mkDerivation {
    pname = "sf-mono";
    version = "latest";
    src = pkgs.fetchzip {
      urls = [
        "${global_settings.ghProxy}/https://github.com/supercomputra/SF-Mono-Font/archive/refs/heads/master.tar.gz"
      ];
      hash = "sha256-3wG3M4Qep7MYjktzX9u8d0iDWa17FSXYnObSoTG2I/o=";
    };
    installPhase = ''
      mkdir -p $out/share/fonts/opentype
      cp *.otf $out/share/fonts/opentype/
    '';
  };

  pingfangSC = pkgs.fetchurl {
    url = "${global_settings.ghProxy}/https://github.com/ZTfer/weui-sketch/raw/refs/heads/master/font/PingFang.ttc";
    hash = "sha256-Mk6r/jcCruJZCr1+8Q6q4YWHRDbsYBnF4qyJsREVXCk=";
  };

  fontPackages =
    if smallFonts then
      [
        pkgs.wqy_microhei
        pkgs.noto-fonts-color-emoji
      ]
    else
      [
        pkgs.sarasa-gothic
        pkgs.noto-fonts-color-emoji
      ];

  sansFont = if smallFonts then "WenQuanYi Micro Hei" else global_settings.font.sans;
  monoFont = if smallFonts then "WenQuanYi Micro Hei Mono" else global_settings.font.mono;

  readme = ''
    ┌────────────────────────────────┬─────┬─────┬─────┬───────┬─────────┬───────┬──────────────────────────────────────────────┐
    │ 字体                           │ 中  │ 日  │ 韩  │ 等宽  │ NerdFont│ Emoji │ 备注                                         │
    ├────────────────────────────────┼─────┼─────┼─────┼───────┼─────────┼───────┼──────────────────────────────────────────────┤
    │ jetbrainsMonoNerdFont          │ ✗   │ ✗   │ ✗   │ ✓     │ ✓       │ △     │ Nerd Font 自带图标字形                       │
    ├────────────────────────────────┼─────┼─────┼─────┼───────┼─────────┼───────┼──────────────────────────────────────────────┤
    │ vistaFontsChs（微软雅黑）      │ ✓   │ ✗   │ ✗   │ ✗     │ ✗       │ ✗     │ 仅简中                                       │
    ├────────────────────────────────┼─────┼─────┼─────┼───────┼─────────┼───────┼──────────────────────────────────────────────┤
    │ sarasa-gothic                  │ ✓   │ ✓   │ ✓   │ ✓¹    │ ✗       │ ✗     │ ①有 Mono/Fixed/Term 等宽变体                 │
    ├────────────────────────────────┼─────┼─────┼─────┼───────┼─────────┼───────┼──────────────────────────────────────────────┤
    │ 霞鹜文楷（lxgw-wenkai）        │ ✓   │ △   │ ✗   │ ✓²    │ ✗       │ ✗     │ ②有 Mono；日文部分字形，小字体下看不清       │
    ├────────────────────────────────┼─────┼─────┼─────┼───────┼─────────┼───────┼──────────────────────────────────────────────┤
    │ maple-mono.NF-CN               │ ✓   │ ✗   │ ✗   │ ✓     │ ✓       │ ✓     │ Nerd Font + 中文等宽，含 Nerd Font 图标。    │
    │                                │     │     │     │       │         │       │ 作者是 L 站的 Song，整体中规中矩             │
    ├────────────────────────────────┼─────┼─────┼─────┼───────┼─────────┼───────┼──────────────────────────────────────────────┤
    │ noto-fonts-color-emoji         │ ✗   │ ✗   │ ✗   │ ✗     │ ✗       │ ✓     │ Google 彩色 Emoji 字体                       │
    ├────────────────────────────────┼─────┼─────┼─────┼───────┼─────────┼───────┼──────────────────────────────────────────────┤
    │ sfMono（SF Mono 苹果等宽）     │ ✗   │ ✗   │ ✗   │ ✓     │ ✗       │ ✗     │ Apple 官方等宽字体，源自 San Francisco 家族  │
    ├────────────────────────────────┼─────┼─────┼─────┼───────┼─────────┼───────┼──────────────────────────────────────────────┤
    │ pingfangSC（苹方）             │ ✓   │ ✗   │ ✗   │ ✗     │ ✗       │ ✗     │ SC/TC/HK 三个比例变体                        │
    └────────────────────────────────┴─────┴─────┴─────┴───────┴─────────┴───────┴──────────────────────────────────────────────┘
  '';
in
if hmStandalone then
  {
    home.packages = fontPackages;

    fonts.fontconfig.enable = true;

    home.file.".config/font.readme.md".text = readme;

    gtk = {
      enable = true;
      gtk3.extraConfig = {
        gtk-font-name = "${sansFont} ${toString global_settings.font.size.gui}";
      };
      gtk4.extraConfig = {
        gtk-font-name = "${sansFont} ${toString global_settings.font.size.gui}";
      };
    };

    dconf.settings = {
      "org/gnome/desktop/interface" = {
        font-name = "${sansFont} ${toString global_settings.font.size.gui}";
      };
    };
  }
else
  {

    i18n = {
      defaultLocale = "en_US.UTF-8";
      supportedLocales = [
        "en_US.UTF-8/UTF-8"
        "zh_CN.UTF-8/UTF-8"
      ];
    };

    environment.systemPackages = [ pkgs.fbterm ];

    fonts = {
      packages =
        fontPackages
        ++ [
          pkgs.nerd-fonts.symbols-only
          #pingfangSC
          #pkgs.maple-mono.NF-CN
          #sfMono
        ];
      fontDir.enable = true;
      fontconfig = {
        enable = true;
        defaultFonts =
          if smallFonts then
            {
              serif = [ "WenQuanYi Micro Hei" ];
              sansSerif = [ "WenQuanYi Micro Hei" ];
              monospace = [ "WenQuanYi Micro Hei Mono" ];
              emoji = [ global_settings.font.emoji ];
            }
          else
            {
              serif = [ global_settings.font.serif ];
              sansSerif = [ global_settings.font.sans ];
              monospace = [ global_settings.font.mono ];
              emoji = [ global_settings.font.emoji ];
            };
      };
    };
    home-manager = {
      users.${username} = {
        home.file.".config/font.readme.md".text = readme;
        gtk = {
          enable = true;
          gtk3.extraConfig = {
            gtk-font-name = "${sansFont} ${toString global_settings.font.size.gui}";
          };
          gtk4.extraConfig = {
            gtk-font-name = "${sansFont} ${toString global_settings.font.size.gui}";
          };
        };
        dconf.settings = {
          "org/gnome/desktop/interface" = {
            font-name = "${sansFont} ${toString global_settings.font.size.gui}";
          };
        };
      };
    };

  }