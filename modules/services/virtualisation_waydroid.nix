{
  pkgs,
  ...
}:
{
  virtualisation.waydroid.enable = true;
  virtualisation.waydroid.package = pkgs.waydroid-nftables;

  services.udev.extraRules = ''
    KERNEL=="video1", SUBSYSTEM=="video4linux", RUN+="${pkgs.coreutils}/bin/rm -f /dev/video1"
    KERNEL=="video2", SUBSYSTEM=="video4linux", RUN+="${pkgs.coreutils}/bin/rm -f /dev/video2"
    KERNEL=="video3", SUBSYSTEM=="video4linux", RUN+="${pkgs.coreutils}/bin/rm -f /dev/video3"
  '';
}
