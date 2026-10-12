{ pkgs, lib, ... }:

let
  inherit (pkgs) util-linux e2fsprogs coreutils;
in
{
  zramSwap = {
    enable = true;
    swapDevices = 1;
    memoryPercent = 50;
    algorithm = "zstd";
  };

  systemd.services."create-swapfile-btrfs" = {
    description = "Create btrfs swap file with NOCOW";
    before = [ "swapfile.swap" ];
    wantedBy = [ "swapfile.swap" ];
    unitConfig.DefaultDependencies = false;
    path = [
      util-linux
      e2fsprogs
      coreutils
    ];
    script = ''
      size=$(${coreutils}/bin/stat -c %s /swapfile 2>/dev/null || echo 0)
      if [ "$size" -ne 10737418240 ]; then
        ${coreutils}/bin/rm -f /swapfile
        ${coreutils}/bin/truncate -s 0 /swapfile
        ${e2fsprogs}/bin/chattr +C /swapfile
        ${util-linux}/bin/fallocate -l 10G /swapfile
        ${coreutils}/bin/chmod 0600 /swapfile
        ${util-linux}/bin/mkswap /swapfile
      fi
    '';
    serviceConfig.Type = "oneshot";
    serviceConfig.RemainAfterExit = true;
  };
}
