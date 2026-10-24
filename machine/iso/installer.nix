{
  config,
  global_settings,
  lib,
  modulesPath,
  pkgs,
  ...
}:
{
  imports = [ (modulesPath + "/installer/cd-dvd/installation-cd-minimal-new-kernel-no-zfs.nix") ];

  networking.hostName = "iso-installer";
  networking.networkmanager.wifi.backend = "iwd";

  isoImage.edition = lib.mkForce "maintenance";
  isoImage.makeBiosBootable = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.trusted-users = [ "nixos" ];

  system.stateVersion = global_settings.stateVersion;
  system.nixos.label = "iso-installer-${config.system.nixos.version}";

  boot.kernelParams = [ "console=ttyS0,115200n8" ];
  boot.supportedFilesystems = [
    "exfat"
    "ntfs"
  ];

  environment.systemPackages = with pkgs; [
    btrfs-progs
    curl
    cryptsetup
    ddrescue
    dosfstools
    e2fsprogs
    ethtool
    exfatprogs
    git
    gptfdisk
    htop
    inetutils
    iproute2
    jq
    lsof
    lvm2
    mdadm
    mtr
    neovim
    nmap
    ntfs3g
    nvme-cli
    p7zip
    parted
    pciutils
    rsync
    smartmontools
    socat
    tcpdump
    tmux
    unzip
    usbutils
    util-linux
    wget
    xfsprogs
    zstd
  ];

  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = lib.mkForce "no";
  users.users.nixos.initialHashedPassword = lib.mkForce "!";
}
