{ config
, lib
, pkgs
, ...
}: {

  #defaultWindowManager = "/run/current-system/sw/bin/gnome-session";

  services.xrdp = {
    enable = true;
    openFirewall = true;
    defaultWindowManager = "gnome-remote-desktop";
  };

  environment.systemPackages = with pkgs; [
    gnome-remote-desktop
  ];
}
