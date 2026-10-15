{
  pkgs,
  lib,
  username,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    xwayland-satellite
    pamixer
    wl-clipboard
    wlrctl
    swayidle
    libxcursor
  ];

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
