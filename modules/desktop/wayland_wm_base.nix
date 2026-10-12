{
  pkgs,
  lib,
  username,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    awww
    brightnessctl
    xdg-desktop-portal-gtk
    libnotify

    wl-clip-persist
    glib
    wayland
    direnv
    wl-clipboard-rs
    playerctl
    bluez
    bluez-tools

    kanshi
    wtype
    brightnessctl
    kitty
  ];

  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config = {
      niri = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "niri" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "niri" ];
      };
    };
  };
}
