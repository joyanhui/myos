{
  pkgs,
  lib,
  username,
  global_settings,
  ...
}:
let
  theme = global_settings.theme;
  iconPkg = pkgs.${theme.iconThemePkg};
  iconName = theme.iconTheme;
  cursorPkg = pkgs.${theme.cursorThemePkg};
  cursorName = theme.cursorTheme;
in
{
  home-manager = {
    users.${username} =
      { config, ... }:
      {
        home.packages = with pkgs; [
          adwaita-icon-theme
          hicolor-icon-theme
          iconPkg
          pkgs.${theme.package}
          cursorPkg
        ];
        gtk = {
          enable = true;
          iconTheme = {
            name = iconName;
            package = iconPkg;

          };
          theme = {
            package = pkgs.${theme.package};
            name = theme.name;
          };
          gtk3.extraConfig = {
            gtk-decoration-layout = "appmenu:";
            gtk-application-prefer-dark-theme = true;
            gtk-cursor-theme-name = cursorName;
          };
          gtk4.extraConfig = {
            "gtk-enable-animations" = true;
          };
          gtk4.theme = config.gtk.theme;
        };
        qt = {
          enable = true;
          platformTheme.name = "gtk";
        };
        dconf.settings = {
          "org/gnome/desktop/interface" = {
            cursor-theme = cursorName;
            color-scheme = "prefer-dark";
            gtk-theme = theme.name;
          };
          "org/gnome/shell/extensions/user-theme" = {
            name = theme.name;
          };
          "org/gnome/desktop/wm/preferences" = {
            theme = theme.name;
          };
        };
        home.file.".icons/default".source = "${cursorPkg}/share/icons/${cursorName}";
      };
  };

}
