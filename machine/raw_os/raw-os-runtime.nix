{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}:
let
  resizeRawImage = pkgs.writeShellScriptBin "resize-raw-image" (
    builtins.readFile ./docs_script/resize-raw-image.sh
  );
  efiArch = pkgs.stdenv.hostPlatform.efiArch;

  installRawUki = pkgs.writeShellScript "install-raw-uki" ''
    set -euo pipefail

    toplevel="''${1:?system toplevel is required}"
    boot_mount="${config.boot.loader.efi.efiSysMountPoint}"
    boot_spec="$toplevel/boot.json"
    target="$boot_mount/EFI/BOOT/BOOTX64.EFI"
    target_dir=$(${pkgs.coreutils}/bin/dirname "$target")
    jq=${pkgs.jq}/bin/jq
    ukify=${pkgs.systemdUkify}/lib/systemd/ukify
    stub=${pkgs.systemd}/lib/systemd/boot/efi/linux${efiArch}.efi.stub

    [ -d "$boot_mount" ] || {
      echo "error: EFI system partition mount point does not exist: $boot_mount" >&2
      exit 1
    }
    [ -f "$boot_spec" ] || {
      echo "error: boot specification was not found: $boot_spec" >&2
      exit 1
    }
    kernel=$($jq -r '."org.nixos.bootspec.v1".kernel // empty' "$boot_spec")
    initrd=$($jq -r '."org.nixos.bootspec.v1".initrd // empty' "$boot_spec")
    init=$($jq -r '."org.nixos.bootspec.v1".init // empty' "$boot_spec")
    kernel_params=$($jq -r '(."org.nixos.bootspec.v1".kernelParams // []) | join(" ")' "$boot_spec")
    [ -f "$kernel" ] || {
      echo "error: kernel from boot specification was not found: $kernel" >&2
      exit 1
    }
    [ -f "$initrd" ] || {
      echo "error: initrd from boot specification was not found: $initrd" >&2
      exit 1
    }
    [ -n "$init" ] || {
      echo "error: init from boot specification was empty" >&2
      exit 1
    }
    [ -f "$stub" ] || {
      echo "error: EFI stub was not found: $stub" >&2
      exit 1
    }
    ${pkgs.coreutils}/bin/mkdir -p "$target_dir"
    temporary=$(${pkgs.coreutils}/bin/mktemp "$target_dir/.BOOTX64.EFI.XXXXXX")
    cleanup() {
      ${pkgs.coreutils}/bin/rm -f "$temporary"
    }
    trap cleanup EXIT

    "$ukify" build \
      --linux "$kernel" \
      --initrd "$initrd" \
      --cmdline "init=$init $kernel_params" \
      --os-release "@$toplevel/etc/os-release" \
      --stub "$stub" \
      --uname "${config.boot.kernelPackages.kernel.modDirVersion}" \
      --efi-arch ${efiArch} \
      --output "$temporary"
    ${pkgs.coreutils}/bin/chmod 0644 "$temporary"
    ${pkgs.coreutils}/bin/sync
    ${pkgs.coreutils}/bin/mv -f "$temporary" "$target"
    temporary=""
    ${pkgs.coreutils}/bin/sync
    echo "updated: $target"
    echo "toplevel: $toplevel"
  '';

  updateExternalEfi = pkgs.writeShellScriptBin "updateExternalEfi" ''
        set -euo pipefail

    w    efibootmgr=${pkgs.efibootmgr}/bin/efibootmgr
        awk=${pkgs.gawk}/bin/awk
        coreutils=${pkgs.coreutils}
        find=${pkgs.findutils}/bin/find
        blkid=${pkgs.util-linux}/bin/blkid
        mount=${pkgs.util-linux}/bin/mount
        umount=${pkgs.util-linux}/bin/umount
        uki="/boot/EFI/BOOT/BOOTX64.EFI"

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
          echo "skip: BootCurrent was not found; no external EFI was updated"
          exit 0
        }

        boot_entry=$(printf '%s\n' "$boot_info" | $awk -v id="$boot_current" '$0 ~ "^Boot" id "[* ]" { print; exit }')
        [ -n "$boot_entry" ] || {
          echo "error: current UEFI boot entry was not found: $boot_current" >&2
          exit 1
        }

        part_uuid=$(printf '%s\n' "$boot_entry" | $awk 'match($0, /HD\([^,]*,GPT,([^,]*),/, m) { print m[1]; exit }')
        internal_esp=$($coreutils/bin/readlink -f /dev/disk/by-partlabel/nixos-esp 2>/dev/null || true)
        if [ -z "$part_uuid" ] && [ -n "$internal_esp" ] && [ -b "$internal_esp" ]; then
          echo "skip: current UEFI boot uses the internal fallback EFI; no external EFI was updated"
          exit 0
        fi

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
        [ -n "$efi_path" ] || {
          echo "error: EFI file path was not found in current UEFI entry" >&2
          exit 1
        }
        if [ "$efi_path" = "/EFI/BOOT/BOOTX64.EFI" ] && [ -z "$part_uuid" ]; then
          echo "skip: current UEFI boot entry uses the internal fallback EFI; no external EFI was updated"
          exit 0
        fi

        internal_part_uuid=""
        if [ -n "$internal_esp" ] && [ -b "$internal_esp" ]; then
          internal_part_uuid=$($blkid -o value -s PARTUUID "$internal_esp" 2>/dev/null || true)
        fi
        if [ -n "$internal_part_uuid" ] && [ -n "$part_uuid" ] && [ "''${part_uuid,,}" = "''${internal_part_uuid,,}" ]; then
          echo "skip: current UEFI boot entry points to internal nixos-esp; no external EFI was updated"
          exit 0
        fi

        [ -n "$part_uuid" ] || {
          echo "error: GPT partition UUID was not found in current external UEFI entry" >&2
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

  boot.loader.external = {
    enable = true;
    installHook = installRawUki;
  };
  boot.loader.efi.canTouchEfiVariables = false;

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
