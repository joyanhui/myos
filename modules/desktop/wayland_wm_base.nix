{
  pkgs,
  lib,
  username,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    awww
    mpvpaper
    swaybg
    brightnessctl
    xdg-desktop-portal-gtk

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

    libnotify
    dex
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
