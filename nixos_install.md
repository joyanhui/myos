nixos install 


## disk and sub vol
lsblk
nvme0n1       259:0    0 465.8G  0 disk 
├─nvme0n1p1   259:1    0   1.7G  0 part 
├─nvme0n1p2   259:2    0    32M  0 part 
├─nvme0n1p3   259:3    0   300M  0 part 
├─nvme0n1p4   259:4    0   100G  0 part 
└─nvme0n1p5   259:5    0 363.7G  0 part
nix-shell -p btrfs-progs
sudo mkfs.fat -F 32 /dev/nvme0n1p3   # 

sudo mkfs.btrfs -f -L NIXOS /dev/nvme0n1p5

sudo mkdir -p /mnt
sudo mount /dev/nvme0n1p5 /mnt
sudo btrfs subvolume create /mnt/root
sudo btrfs subvolume create /mnt/home
sudo btrfs subvolume create /mnt/nix
sudo umount /mnt

sudo mount -o compress=zstd,subvol=root /dev/nvme0n1p5 /mnt
sudo mkdir /mnt/{home,nix}
sudo mount -o compress=zstd,subvol=home /dev/nvme0n1p5 /mnt/home
sudo mount -o compress=zstd,noatime,subvol=nix /dev/nvme0n1p5 /mnt/nix
sudo mkdir /mnt/boot
sudo mount /dev/nvme0n1p3 /mnt/boot

## install
sudo nixos-generate-config --root /mnt
sudo nano /mnt/etc/nixos/configuration.nix # add line and del gnome
```nix

  boot = {
    tmp.cleanOnBoot = true;
    kernelPackages = pkgs.linuxPackages_latest;
    loader = {
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        extraEntries = ''
          menuentry "Windows efi" {
              search --file --no-floppy --set=root /EFI/Microsoft/Boot/bootmgfw.efi
              chainloader (''${root})/EFI/Microsoft/Boot/bootmgfw.efi
          }
        '';
        theme = (
          pkgs.sleek-grub-theme.override {
            withStyle = "dark"; # bigSur dark light orange
            withBanner = "LYH";
          }
        );
      };
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
  };
  environment.gnome.excludePackages = with pkgs; [ gnome-tour gnome-user-docs ];
nix.settings.experimental-features = [ "nix-command" "flakes" ];
environment.systemPackages = with pkgs; [ git vim helix wget fish ntfs3g mihomo];
```
sudo nano /mnt/etc/nixos/hardware-configuration.nix 
```nix

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/05588e47-3d2d-48fd-8958-0afb3b563dab";
    fsType = "btrfs";
    options = ["subvol=root" "compress=zstd"];
  };

  fileSystems."/home" = {
    device = "/dev/disk/by-uuid/05588e47-3d2d-48fd-8958-0afb3b563dab";
    fsType = "btrfs";
    options = ["subvol=home" "compress=zstd"];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/05588e47-3d2d-48fd-8958-0afb3b563dab";
    fsType = "btrfs";
    options = ["subvol=nix" "compress=zstd" "noatime"];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/AE3C-6252";
    fsType = "vfat";
    options = ["fmask=0022" "dmask=0022"];
  };

  swapDevices = [ ];
```
cd /mnt

sudo nixos-install  --option substituters https://mirrors.sjtug.sjtu.edu.cn/nix-channels/store/

## add user
cd /mnt

sudo nixos-enter 

useradd -m nixos
passwd y
usermod -aG wheel nixos

cp -r /run/media/nixos/NTFS128G/myws/ /mnt/home/nixos/
chown -R nixos:wheel /home/nixos/myws


export proxy="http://192.168.1.110:7890" # phone or other pc with clash/mihomo
export http_proxy=$proxy && export https_proxy=$proxy && export ftp_proxy=$proxy && export no_proxy="localhost, 127.0.0.1, ::1"


sudo  nixos-rebuild switch --flake /home/nixos/myws/os-config#tb_amd --option substituters https://cache.nixos.org
