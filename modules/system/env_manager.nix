{
  config,
  lib,
  pkgs,
  username,
  global_settings,
  ...
}:
let
  extraEnvVars = config.envManager.extraVars or { };
  theme = global_settings.theme;
  iconPkg = pkgs.${theme.iconThemePkg};
  fcitx5Pkg = lib.attrByPath [ "i18n" "inputMethod" "package" ] pkgs.qt6Packages.fcitx5-with-addons config;
  gstOut = pkg: lib.getOutput "out" pkg;
  gstPluginPath = lib.concatStringsSep ":" (
    map (pkg: "${gstOut pkg}/lib/gstreamer-1.0") (with pkgs.gst_all_1; [
      gstreamer
      gst-plugins-base
      gst-plugins-good
      gst-plugins-bad
      gst-plugins-ugly
      gst-libav
    ])
  );

  xdgDataDirsBase = lib.concatStringsSep ":" [
    "${iconPkg}/share"
    "${fcitx5Pkg}/share"
    "${pkgs.fcitx5-rime}/share"
    "${pkgs.hicolor-icon-theme}/share"
    "/home/${username}/.local/share/flatpak/exports/share"
    "/var/lib/flatpak/exports/share"
    "/home/${username}/.nix-profile/share"
    "/home/${username}/.local/state/nix/profile/share"
    "/etc/profiles/per-user/${username}/share"
    "/nix/var/nix/profiles/default/share"
    "/run/current-system/sw/share"
  ];
  envVars = {
    REPO_DIR = global_settings.repoDir;
    LOT_CFG_FILE = "$HOME/myws/lot-manager-aio";
    EDITOR = global_settings.editor;
    VISUAL = global_settings.editor;
    SUDO_EDITOR = global_settings.editor;
    GIT_EDITOR = global_settings.editor;

    NPM_CONFIG_PREFIX = "/home/${username}/.npm-global";

    http_proxy = global_settings.systemProxy or "";
    https_proxy = global_settings.systemProxy or "";
    all_proxy = global_settings.systemProxy or "";
    HTTP_PROXY = global_settings.systemProxy or "";
    HTTPS_PROXY = global_settings.systemProxy or "";
    ALL_PROXY = global_settings.systemProxy or "";
    no_proxy = "127.0.0.1,localhost";
    NO_PROXY = "127.0.0.1,localhost";

    XCURSOR_SIZE = 32;
    XCURSOR_THEME = theme.cursorTheme;
    FONTCONFIG_PATH = "/etc/fonts";

    GTK_IM_MODULE = "fcitx";    QT_IM_MODULE = "fcitx";
    QT6_IM_MODULE = "fcitx";
    QT_IM_MODULES = "fcitx;wayland;ibus";
    SDL_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "fcitx";
    CLUTTER_IM_MODULE = "fcitx";
    INPUT_METHOD = "fcitx";
    IMSETTINGS_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";

    LC_CTYPE = "zh_CN.UTF-8";

    GST_PLUGIN_SYSTEM_PATH_1_0 = gstPluginPath;
    GST_PLUGIN_SCANNER_1_0 = "${gstOut pkgs.gst_all_1.gstreamer}/libexec/gstreamer-1.0/gst-plugin-scanner";
    XDG_DATA_DIRS = "${pkgs.gtk3}/share/gsettings-schemas/${pkgs.gtk3.name}:${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}:${xdgDataDirsBase}";

    WEBKIT_DISABLE_COMPOSITING_MODE = "1";

    WINEDLLOVERRIDES = "winemenubuilder.exe=d";

    PATH = [
      "/home/${username}/.local/bin"
      "/home/${username}/.local/share/pnpm/bin"
      "/home/${username}/.bun/bin"
      "/home/${username}/.npm-global/bin"
      "/home/${username}/myworkspace/my-opt"
      "/home/${username}/myworkspace/my-opt/cli-proxy-api-plus"
    ];
  }
  // extraEnvVars;
  pathPrefixDirs = envVars.PATH;
  fishPathBlock = ''
    set -l _npm_dirs ${lib.concatMapStringsSep " " (d: ''"${d}"'') pathPrefixDirs}
    for _d in $_npm_dirs
        if not contains -- $_d $PATH
            set -gx PATH $_d $PATH
        end
    end
  '';
  fishEnvFile = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: value:
      if name == "DISPLAY" then
        ''
          set -l _xw_display (ps -C Xwayland -o args= 2>/dev/null | string match -r ':\d+' | head -1)
          if test -n "$_xw_display"
              set -gx DISPLAY "$_xw_display"
          else
              set -gx DISPLAY ":0"
          end''
      else
        "set -gx ${name} \"${toString value}\""
    ) (lib.removeAttrs envVars [ "PATH" ])
    ++ [ fishPathBlock ]
  );
in
{
  options.envManager.extraVars = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
  };

  config = {
    environment.sessionVariables = lib.removeAttrs envVars [ "XMODIFIERS" "XDG_DATA_DIRS" "PATH" "GIO_EXTRA_MODULES" ];
    environment.variables.XMODIFIERS = envVars.XMODIFIERS;

    home-manager.users.${username} = {
      home.sessionVariables = lib.removeAttrs envVars [ "PATH" ];
      home.sessionPath = envVars.PATH;

      xdg.configFile."fish/conf.d/90-env.fish".text = fishEnvFile;

      xdg.configFile."environment.d/20-session-vars.conf".text =
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (name: value: "${name}=${toString value}") (
            lib.removeAttrs envVars [ "PATH" ]
          )
        );
    };
  };
}
