{
  pkgs,
  lib,
  modulesPath,
  ...
}:
let
  resizeRawImage = pkgs.writeShellScriptBin "resize-raw-image" (builtins.readFile ./docs_script/resize-raw-image.sh);

  updateGrubx64LoopbackEfi = pkgs.writeShellScriptBin "update-grubx64-loopback-efi" ''
    set -e
    export PATH=${pkgs.coreutils}/bin:${pkgs.util-linux}/bin:${pkgs.gnused}/bin:${pkgs.gnugrep}/bin:$PATH
    bootjson=/run/current-system/boot.json
    if [ ! -f "$bootjson" ]; then
      echo "error: $bootjson not found (run after nixos-rebuild)"
      exit 1
    fi
    kernel=$(${pkgs.jq}/bin/jq -r '."org.nixos.bootspec.v1".kernel' "$bootjson")
    initrd=$(${pkgs.jq}/bin/jq -r '."org.nixos.bootspec.v1".initrd' "$bootjson")
    init=$(${pkgs.jq}/bin/jq -r '."org.nixos.bootspec.v1".init' "$bootjson")
    params=$(${pkgs.jq}/bin/jq -r '."org.nixos.bootspec.v1".kernelParams | join(" ")' "$bootjson")
    tmp=$(mktemp -d)
    cat > "$tmp/grub.cfg" << EOF_GRUB
    insmod ntfs
    insmod part_gpt
    insmod btrfs
    insmod search
    insmod search_fs_file
    insmod configfile
    insmod normal
    insmod linux
    insmod loopback
    insmod all_video
    search --no-floppy --set=root --file /OS-img/nixos.raw
    set vdisk=(\$root)/OS-img/nixos.raw
    loopback loop0 \$vdisk
    linux (loop0,gpt2)$kernel init=$init $params
    initrd (loop0,gpt2)$initrd
    boot
    EOF_GRUB
    ${pkgs.grub2_efi}/bin/grub-mkstandalone -O x86_64-efi \
      -d ${pkgs.grub2_efi}/lib/grub/x86_64-efi \
      --compress=no \
      --modules="ntfs part_gpt btrfs ext2 fat search search_fs_file configfile normal linux echo all_video loopback" \
      --output="$tmp/grubx64.efi" \
      "boot/grub/grub.cfg=$tmp/grub.cfg"
    updated=""
    for d in /sys/class/block/*; do
      dev=$(basename "$d")
      case "$dev" in
        loop[0-9]p[0-9]*|sd[a-z][0-9]*|nvme[0-9]n[0-9]p[0-9]*|vd[a-z][0-9]*|mmcblk[0-9]p[0-9]*) ;;
        *) continue ;;
      esac
      [ -b "/dev/$dev" ] || continue
      mnt=/mnt/esp-check
      mkdir -p "$mnt"
      if mount -t vfat "/dev/$dev" "$mnt" 2>/dev/null; then
        if [ -f "$mnt/EFI/BOOT/BOOTX64.EFI" ] || [ -f "$mnt/EFI/BOOT/grubx64.efi" ]; then
          cp -f "$tmp/grubx64.efi" "$mnt/EFI/BOOT/BOOTX64.EFI"
          cp -f "$tmp/grubx64.efi" "$mnt/EFI/BOOT/grubx64.efi"
          sync
          updated="$updated /dev/$dev"
        fi
        umount "$mnt" 2>/dev/null || true
      fi
    done
    rm -rf "$tmp"
    if [ -n "$updated" ]; then
      echo "EFI partitions updated:$updated"
    else
      echo "warning: no EFI partition with grub files found"
    fi
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
    updateGrubx64LoopbackEfi
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
    device = "/dev/disk/by-partlabel/ESP";
    fsType = "vfat";
  };
}
