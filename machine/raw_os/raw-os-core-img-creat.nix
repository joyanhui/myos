{
  config,
  pkgs,
  lib,
  modulesPath,
  global_settings,
  ...
}:
let
  imageRootTree = pkgs.runCommand "nixos-topdirs" { } ''
    mkdir -p $out/run $out/var $out/tmp $out/home $out/root $out/boot \
      $out/dev $out/proc $out/sys $out/usr $out/bin $out/lib $out/lib64 \
      $out/sbin $out/opt $out/srv $out/mnt $out/media $out/lost+found
    chmod 1777 $out/tmp
    mkdir -p $out/var/tmp
    chmod 1777 $out/var/tmp
    mkdir -p $out/usr/bin
    ln -s ${pkgs.coreutils}/bin/env $out/usr/bin/env
    mkdir -p $out/etc
    cp -a ${config.system.build.toplevel}/etc/. $out/etc/
    mkdir -p $out/nix/var/nix/profiles
    ln -s ${config.system.build.toplevel} $out/nix/var/nix/profiles/system-1-link
    ln -s system-1-link $out/nix/var/nix/profiles/system
    ln -s ${config.system.build.toplevel} $out/run/current-system
    ln -s ${config.system.build.toplevel}/init $out/init
    ln -s ${config.system.build.toplevel}/init $out/sbin/init
  '';
in
{
  imports = [
    ./raw-os-runtime.nix
    (modulesPath + "/image/repart.nix")
  ];

  system.image.id = "nixos-img";

  nixpkgs.config.allowUnfree = true;

  i18n.defaultLocale = "C.UTF-8";
  i18n.supportedLocales = [ "C.UTF-8/UTF-8" ];

  networking.networkmanager.enable = true;
  time.timeZone = "Asia/Shanghai";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.substituters = [
    "https://mirror.sjtu.edu.cn/nix-channels/store"
    "https://mirrors.ustc.edu.cn/nix-channels/store"
    "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
    "https://cache.nixos.org"
  ];
  nix.settings.trusted-users = [
    "root"
    "nixos"
  ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
  ];

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    password = "nixos";
    shell = pkgs.zsh;
  };
  security.sudo.wheelNeedsPassword = false;

  programs.fish.enable = true;
  programs.git.enable = true;
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    promptInit = "";
    interactiveShellInit = ''
      source ${pkgs.zsh-autosuggestions}/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
      source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    '';
  };

  system.stateVersion = global_settings.stateVersion;

  environment.systemPackages = with pkgs; [
    coreutils
    bash
    systemd
    util-linux
    procps
    gnugrep
    gnused
    gawk
    findutils
    gnutar
    git-crypt
    transcrypt
    gzip
    bzip2
    xz
    zstd
    which
    less
    file
    diffutils
    patch
    e2fsprogs
    kmod
    git
    fish
    networkmanager
    helix
    usbutils
    pciutils
    parted
    gptfdisk
    btrfs-progs
    dosfstools
    fastfetch
    wget
    curl
    yazi
    unzip
    p7zip
    psmisc
    htop
    iftop
    fd
    tree
    jq
    bat
    dos2unix
    dnsutils
    iproute2
    tcpdump
    tmux
    openssl
    ntfs3g
    inetutils
    exfat
    sshfs-fuse
    smartmontools
    nvme-cli
    efibootmgr
    cryptsetup
    qemu-utils
    rsync
  ];

  image.repart = {
    name = "nixos";
    sectorSize = 512;
    partitions = {
      "esp" = {
        contents =
          let
            efiArch = pkgs.stdenv.hostPlatform.efiArch;
          in
          {
            "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source = config.system.build.rawOsBootEfi;
            "/EFI/NixOS/raw-os/grub.cfg".source = config.system.build.rawOsBootConfig;
            "/EFI/NixOS/raw-os/nixos-current.efi".source =
              "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
            "/EFI/NixOS/raw-os/nixos-generation-1.efi".source =
              "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
          };
        repartConfig = {
          Type = "esp";
          Format = "vfat";
          SizeMinBytes = "1G";
          SizeMaxBytes = "1G";
          Label = "nixos-esp";
        };
      };
      "root" = {
        storePaths = [
          config.system.build.toplevel
          config.system.path
        ];
        contents = {
          "/".source = imageRootTree;
        };
        repartConfig = {
          Type = "root";
          Format = "btrfs";
          Label = "nixos-root";
          SizeMinBytes = "10G";
          SizeMaxBytes = "10G";
        };
      };
    };
  };
}
