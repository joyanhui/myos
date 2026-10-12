{ pkgs, ... }:

{
  services.autofs = {
    enable = true;
    autoMaster =
      let
        # ExFAT -fstype=exfat,uid=1000,gid=1000,umask=022,dmask=022,fmask=133 :/dev/disk/by-label/NTFS128G
        # sudo ntfsfix /dev/disk/by-label/NTFS128G
        mapConf = pkgs.writeText "autofs.mnt" ''

          NVME_NTFS  -fstype=ntfs3,force,uid=1000,gid=1000,umask=022,dmask=022,fmask=133 :/dev/disk/by-label/NTFS
          DATA128G  -fstype=ntfs3,force,uid=1000,gid=1000,umask=022,dmask=022,fmask=133 :/dev/disk/by-label/NTFS128G
          HDD25  -fstype=exfat,force,uid=1000,gid=1000,umask=022,dmask=022,fmask=133 :/dev/disk/by-label/HDD25
        '';
      in
      ''
        /mnt_auto/autofs ${mapConf} --timeout 35
      '';
  };

}
