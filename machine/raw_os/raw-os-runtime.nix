{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}:
let
  resizeRawImage = pkgs.writeShellScriptBin "resize-raw-image" (builtins.readFile ./docs_script/resize-raw-image.sh);

  updateExternalEfi = pkgs.writeShellScriptBin "updateExternalEfi" ''
    set -euo pipefail

    efibootmgr=${pkgs.efibootmgr}/bin/efibootmgr
    awk=${pkgs.gawk}/bin/awk
    coreutils=${pkgs.coreutils}
    find=${pkgs.findutils}/bin/find
    blkid=${pkgs.util-linux}/bin/blkid
    mount=${pkgs.util-linux}/bin/mount
    umount=${pkgs.util-linux}/bin/umount
    uki="/boot/EFI/Linux/${config.system.boot.loader.ukiFile}"

    [ "$(id -u)" -eq 0 ] || {
      echo "error: updateExternalEfi must run as root" >&2
      exit 1
    }
    [ -d /sys/firmware/efi ] || {
      echo "error: UEFI runtime is not available" >&2
      exit 1
    }

    boot_info=$($efibootmgr -v)
    boot_current=$(printf '%s\n' "$boot_info" | $awk '/^BootCurrent:/ { print $2; exit }')
    [ -n "$boot_current" ] || {
      echo "error: BootCurrent was not found" >&2
      exit 1
    }

    boot_entry=$(printf '%s\n' "$boot_info" | $awk -v id="$boot_current" '$0 ~ "^Boot" id "[* ]" { print; exit }')
    [ -n "$boot_entry" ] || {
      echo "error: current UEFI boot entry was not found: $boot_current" >&2
      exit 1
    }

    part_uuid=$(printf '%s\n' "$boot_entry" | $awk 'match($0, /HD\([^,]*,GPT,([^,]*),/, m) { print m[1]; exit }')
    efi_path=$(printf '%s\n' "$boot_entry" | $awk '
      match($0, /File\(([^)]*)\)/, m) {
        path=m[1]
        gsub(/\\/, "/", path)
        print path
        exit
      }
      match($0, /\/\\EFI\\[^[:space:]]*/, m) {
        path=m[0]
        sub(/^\/\\/, "/", path)
        gsub(/\\/, "/", path)
        print path
        exit
      }
    ')
    [ -n "$part_uuid" ] || {
      echo "error: GPT partition UUID was not found in current UEFI entry" >&2
      exit 1
    }
    [ -n "$efi_path" ] || {
      echo "error: EFI file path was not found in current UEFI entry" >&2
      exit 1
    }
    case "$efi_path" in
      /EFI/*) ;;
      *)
        echo "error: unsupported EFI file path: $efi_path" >&2
        exit 1
        ;;
    esac
    case "$efi_path" in
      *..*)
        echo "error: invalid EFI file path: $efi_path" >&2
        exit 1
        ;;
    esac

    esp_link=$($find /dev/disk/by-partuuid -maxdepth 1 -type l -iname "$part_uuid" -print -quit)
    [ -n "$esp_link" ] || {
      echo "error: ESP partition was not found: $part_uuid" >&2
      exit 1
    }
    esp=$($coreutils/bin/readlink -f "$esp_link")
    [ -b "$esp" ] || {
      echo "error: EFI partition device is not available: $esp" >&2
      exit 1
    }
    [ "$($blkid -o value -s TYPE "$esp" 2>/dev/null)" = "vfat" ] || {
      echo "error: EFI partition is not FAT32: $esp" >&2
      exit 1
    }

    [ -f "$uki" ] || {
      echo "error: current system UKI was not found: $uki" >&2
      exit 1
    }

    mountpoint=$($coreutils/bin/mktemp -d /run/updateExternalEfi.XXXXXX)
    temporary=""
    cleanup() {
      [ -n "$temporary" ] && $coreutils/bin/rm -f "$temporary"
      $umount "$mountpoint" 2>/dev/null || true
      $coreutils/bin/rmdir "$mountpoint" 2>/dev/null || true
    }
    trap cleanup EXIT

    $mount -t vfat "$esp" "$mountpoint"
    target="$mountpoint$efi_path"
    target_dir=$($coreutils/bin/dirname "$target")
    $coreutils/bin/mkdir -p "$target_dir"
    temporary=$($coreutils/bin/mktemp "$target_dir/.updateExternalEfi.XXXXXX")
    $coreutils/bin/cp --reflink=auto "$uki" "$temporary"
    $coreutils/bin/chmod 0644 "$temporary"
    $coreutils/bin/sync
    $coreutils/bin/mv -f "$temporary" "$target"
    temporary=""
    $coreutils/bin/sync
    echo "updated: $efi_path"
    echo "source: $uki"
    echo "esp: $esp"
  '';
in
{
  imports = [
    (modulesPath + "/profiles/minimal.nix")
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.supportedFilesystems = [ "ntfs3" ];

  boot.initrd.kernelModules = [
    "loop"
    "ntfs3"
  ];
  boot.initrd.availableKernelModules = [
    "nvme"
    "ahci"
    "libahci"
    "libata"
    "sd_mod"
    "virtio_pci"
    "virtio_blk"
    "usb-storage"
    "xhci_pci"
    "ehci_pci"
    "ext4"
    "xfs"
    "btrfs"
    "vfat"
    "exfat"
  ];
  boot.initrd.systemd.initrdBin = [ pkgs.util-linux ];
  boot.initrd.systemd.services.nixos-img-loop-for-root = {
    description = "Ensure nixos-root: skip when root partition present, else loop nixos.raw from host partition";
    wantedBy = [ "initrd.target" ];
    before = [
      "initrd-root-device.target"
      "sysroot.mount"
    ];
    after = [ "systemd-udevd.service" ];
    path = with pkgs; [
      util-linux
      coreutils
      kmod
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      dbg() { echo "[imgloop] $*" > /dev/console 2>&1; echo "IMGLOOP:$*" > /dev/ttyS0 2>/dev/null || true; }
      devglob='/dev/vd[a-z][0-9]* /dev/sd[a-z][0-9]* /dev/nvme[0-9]n[0-9]p[0-9]* /dev/hd[a-z][0-9]* /dev/mmcblk[0-9]p[0-9]*'
      dbg "start"
      i=0
      while [ $i -lt 10 ]; do
        any=""
        for dev in $devglob; do [ -b "$dev" ] && any=1; done
        [ -n "$any" ] && break
        dbg "wait $i"
        sleep 1; i=$((i+1))
      done
      dbg "devices: $(ls $devglob 2>/dev/null | tr '\n' ' ')"
      for dev in $devglob; do
        [ -b "$dev" ] || continue
        if [ "$(blkid -o value -s LABEL "$dev" 2>/dev/null)" = "nixos-root" ]; then
          dbg "root present directly on $dev, skip"
          exit 0
        fi
      done
      dbg "no direct root, scan host partitions"
      hostdev=""
      for dev in $devglob; do
        [ -b "$dev" ] || continue
        t=$(blkid -o value -s TYPE "$dev" 2>/dev/null || true)
        [ "$t" = "ntfs" ] || continue
        mkdir -p /host
        dbg "try mount $dev"
        mk_err=$(timeout 4 mount -t ntfs3 "$dev" /host 2>&1)
        if [ $? -eq 0 ]; then
          if [ -f /host/OS-img/nixos.raw ]; then
            dbg "found nixos.raw on $dev"
            hostdev="$dev"
            break
          fi
          dbg "no nixos.raw on $dev"
          umount /host 2>/dev/null || true
        else
          dbg "mount $dev failed: $mk_err"
        fi
      done
      [ -n "$hostdev" ] || { dbg "no host partition with nixos.raw"; exit 1; }
      dbg "losetup nixos.raw"
      lu_err=$(losetup -fP /host/OS-img/nixos.raw 2>&1)
      if [ $? -ne 0 ]; then
        dbg "losetup failed: $lu_err"
        exit 1
      fi
      udevadm trigger --subsystem-match=block 2>/dev/null || true
      udevadm settle --timeout=10 2>/dev/null || true
      dbg "loop partitions: $(ls /dev/loop*p* 2>/dev/null | tr '\n' ' ')"
      mkdir -p /dev/disk/by-partlabel
      for p in /dev/loop*p*; do
        [ -b "$p" ] || continue
        lbl=$(blkid -o value -s LABEL "$p" 2>/dev/null || true)
        [ -n "$lbl" ] || continue
        ln -sf "$p" "/dev/disk/by-partlabel/$lbl"
        dbg "by-partlabel $lbl -> $p"
      done
      dbg "done"
      exit 0
    '';
  };

  hardware.enableAllHardware = true;
  hardware.enableAllFirmware = true;
  hardware.firmware = lib.mkForce (
    with pkgs;
    [
      linux-firmware
      ipw2200-firmware
      rtl8192su-firmware
      rt5677-firmware
      rtl8761b-firmware
      zd1211fw
      alsa-firmware
      sof-firmware
      libreelec-dvb-firmware
      broadcom-bt-firmware
      b43Firmware_5_1_138
      b43Firmware_6_30_163_46
      facetimehd-calibration
      facetimehd-firmware
      wireless-regdb
    ]
  );

  services.getty.autologinUser = "nixos";

  environment.sessionVariables.PATH = [
    "/run/current-system/sw/bin"
    "/run/current-system/sw/sbin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
  ];
  environment.systemPackages = with pkgs; [
    updateExternalEfi
    resizeRawImage
    qemu-utils
    gptfdisk
    btrfs-progs
    jq
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-partlabel/nixos-root";
    fsType = "btrfs";
    options = [ "compress=zstd" ];
  };

  fileSystems."/var" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "mode=755" ];
  };

  fileSystems."/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "mode=1777" ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-partlabel/nixos-esp";
    fsType = "vfat";
  };
}
