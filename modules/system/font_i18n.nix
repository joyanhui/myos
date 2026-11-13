{
  pkgs,
  global_settings,
  username,
  hmStandalone ? false,
  smallFonts ? false,
  ...
}:
let
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
    │ sarasa-gothic                  │ ✓   │ ✓   │ ✓   │ ✓¹    │ ✗       │ ✗     │ ①有 Mono/Fixed/Term 等宽变体                 │
    ├────────────────────────────────┼─────┼─────┼─────┼───────┼─────────┼───────┼──────────────────────────────────────────────┤
    │ noto-fonts-color-emoji         │ ✗   │ ✗   │ ✗   │ ✗     │ ✗       │ ✓     │ Google 彩色 Emoji 字体                       │
    └────────────────────────────────┴─────┴─────┴─────┴───────┴─────────┴───────┴──────────────────────────────────────────────┘
  '';
in
if hmStandalone then
  {
    home.packages = fontPackages ++ [ pkgs.nerd-fonts.symbols-only ];

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