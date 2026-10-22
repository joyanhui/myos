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

  rawOsGrubConfig = pkgs.writeText "raw-os-grub.cfg" ''
    set timeout=5
    set default=0

    menuentry 'NixOS current (generation 1)' {
      set root=
      search --no-floppy --file --set=root /EFI/NixOS/raw-os/nixos-generation-1.efi
      if [ -n "$root" ]; then
        chainloader ($root)/EFI/NixOS/raw-os/nixos-generation-1.efi
      else
        echo 'NixOS generation 1 was not found'
        sleep 3
      fi
    }

    menuentry 'NixOS current' {
      set root=
      search --no-floppy --file --set=root /EFI/NixOS/raw-os/nixos-current.efi
      if [ -n "$root" ]; then
        chainloader ($root)/EFI/NixOS/raw-os/nixos-current.efi
      else
        echo 'NixOS current EFI was not found'
        sleep 3
      fi
    }

    menuentry 'Windows Boot Manager' {
      set windows=
      search --no-floppy --file --set=windows /EFI/Microsoft/Boot/bootmgfw.efi
      if [ -n "$windows" ]; then
        set root="$windows"
        chainloader ($root)/EFI/Microsoft/Boot/bootmgfw.efi
      else
        echo 'Windows Boot Manager was not found'
        sleep 3
      fi
    }
  '';

  rawOsEmbeddedGrubConfig = pkgs.writeText "raw-os-embedded-grub.cfg" ''
    set cfg=
    search --no-floppy --file --set=cfg /EFI/NixOS/raw-os/grub.cfg
    if [ -n "$cfg" ]; then
      configfile ($cfg)/EFI/NixOS/raw-os/grub.cfg
    else
      echo 'Raw OS boot menu was not found'
      sleep 3
    fi
  '';

  rawOsBootEfi = pkgs.runCommand "raw-os-bootx64-efi" { } ''
    ${pkgs.grub2_efi}/bin/grub-mkstandalone \
      --format=${pkgs.grub2_efi.grubTarget} \
      --modules="part_gpt fat search search_fs_file configfile chain normal echo sleep" \
      --output="$out" \
      "boot/grub/grub.cfg=${rawOsEmbeddedGrubConfig}"
  '';

  rawOsExternalEmbeddedGrubConfig = pkgs.writeText "raw-os-external-embedded-grub.cfg" ''
    set windows=
    search --no-floppy --file --set=windows /EFI/Microsoft/Boot/bootmgfw.efi
    set host=
    search --no-floppy --file --set=host /OS-img/nixos.raw
    if [ -z "$host" ]; then
      echo 'Raw OS image was not found on an NTFS partition'
      sleep 5
    else
      loopback raw ($host)/OS-img/nixos.raw
      configfile (raw,gpt1)/EFI/NixOS/raw-os/grub.cfg
    fi
  '';

  rawOsExternalBootEfi = pkgs.runCommand "raw-os-external-boot-efi" { } ''
    ${pkgs.grub2_efi}/bin/grub-mkstandalone \
      --format=${pkgs.grub2_efi.grubTarget} \
      --modules="part_gpt fat ntfs search search_fs_file loopback configfile chain normal echo sleep" \
      --output="$out" \
      "boot/grub/grub.cfg=${rawOsExternalEmbeddedGrubConfig}"
  '';

  installRawBoot = pkgs.writeShellScript "install-raw-boot" ''
    set -euo pipefail

    toplevel="''${1:?system toplevel is required}"
    boot_mount="${config.boot.loader.efi.efiSysMountPoint}"
    profiles_dir=/nix/var/nix/profiles
    target_data="$boot_mount/EFI/NixOS/raw-os"
    jq=${pkgs.jq}/bin/jq
    ukify=${pkgs.systemdUkify}/lib/systemd/ukify
    stub=${pkgs.systemd}/lib/systemd/boot/efi/linux${efiArch}.efi.stub
    coreutils=${pkgs.coreutils}
    grep=${pkgs.gnugrep}/bin/grep
    tmp_root=$($coreutils/bin/mktemp -d /run/raw-os-boot.XXXXXX)
    generation_list="$tmp_root/generations"
    current_toplevel=$($coreutils/bin/readlink -f "$toplevel")

    cleanup() {
      [ -z "''${temporary:-}" ] || $coreutils/bin/rm -f "$temporary"
      $coreutils/bin/rm -rf "$tmp_root"
    }
    trap cleanup EXIT

    [ -d "$boot_mount" ] || {
      echo "error: EFI system partition mount point does not exist: $boot_mount" >&2
      exit 1
    }
    [ -f "$toplevel/boot.json" ] || {
      echo "error: boot specification was not found: $toplevel/boot.json" >&2
      exit 1
    }
    $coreutils/bin/mkdir -p "$target_data" "$tmp_root"
    : > "$generation_list"

    build_uki() {
      generation="$1"
      system_path="$2"
      output_name="$3"
      boot_spec="$system_path/boot.json"
      kernel=$($jq -r '."org.nixos.bootspec.v1".kernel // empty' "$boot_spec")
      initrd=$($jq -r '."org.nixos.bootspec.v1".initrd // empty' "$boot_spec")
      init=$($jq -r '."org.nixos.bootspec.v1".init // empty' "$boot_spec")
      initrd_secrets=$($jq -r '."org.nixos.bootspec.v1".initrdSecrets // empty' "$boot_spec")
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
      initrd_copy="$tmp_root/$output_name.initrd"
      $coreutils/bin/cp "$initrd" "$initrd_copy"
      if [ -n "$initrd_secrets" ]; then
        [ -x "$initrd_secrets" ] || {
          echo "error: initrd secrets appender was not found: $initrd_secrets" >&2
          exit 1
        }
        "$initrd_secrets" "$initrd_copy"
      fi
      "$ukify" build \
        --linux "$kernel" \
        --initrd "$initrd_copy" \
        --cmdline "init=$init $kernel_params" \
        --os-release "@$system_path/etc/os-release" \
        --stub "$stub" \
        --uname "${config.boot.kernelPackages.kernel.modDirVersion}" \
        --efi-arch ${efiArch} \
        --output "$tmp_root/$output_name"
      [ -s "$tmp_root/$output_name" ] || {
        echo "error: UKI was not created: $output_name" >&2
        exit 1
      }
    }

    generation_candidates="$tmp_root/generation-candidates"
    sorted_candidates="$tmp_root/sorted-generations"
    : > "$generation_candidates"
    for generation_link in "$profiles_dir"/system-*-link; do
      [ -e "$generation_link" ] || continue
      generation_name=$($coreutils/bin/basename "$generation_link")
      generation=''${generation_name#system-}
      generation=''${generation%-link}
      case "$generation" in
        ""|*[!0-9]*) continue ;;
      esac
      system_path=$($coreutils/bin/readlink -f "$generation_link") || continue
      [ -f "$system_path/boot.json" ] || continue
      printf '%s\t%s\n' "$generation" "$system_path" >> "$generation_candidates"
    done
    $coreutils/bin/sort -t "$(printf '\t')" -k1,1nr "$generation_candidates" > "$sorted_candidates"

    current_generation=""
    while IFS="$(printf '\t')" read -r generation system_path; do
      [ -n "$generation" ] || continue
      if [ "$system_path" = "$current_toplevel" ]; then
        current_generation="$generation"
        break
      fi
    done < "$generation_candidates"

    selected_generations="$tmp_root/selected-generations"
    : > "$generation_list"
    : > "$selected_generations"
    selected_count=0
    if [ -n "$current_generation" ]; then
      printf '%s\n' "$current_generation" >> "$generation_list"
      printf '%s\t%s\n' "$current_generation" "$current_toplevel" >> "$selected_generations"
      selected_count=1
    fi
    while IFS="$(printf '\t')" read -r generation system_path; do
      [ -n "$generation" ] || continue
      [ "$generation" = "$current_generation" ] && continue
      [ "$selected_count" -ge 8 ] && break
      printf '%s\n' "$generation" >> "$generation_list"
      printf '%s\t%s\n' "$generation" "$system_path" >> "$selected_generations"
      selected_count=$((selected_count + 1))
    done < "$sorted_candidates"

    while IFS="$(printf '\t')" read -r generation system_path; do
      [ -n "$generation" ] || continue
      build_uki "$generation" "$system_path" "nixos-generation-$generation.efi"
    done < "$selected_generations"

    build_uki current "$current_toplevel" nixos-current.efi

    install_file() {
      source="$1"
      target="$2"
      target_dir=$($coreutils/bin/dirname "$target")
      temporary=$($coreutils/bin/mktemp "$target_dir/.raw-os-$($coreutils/bin/basename "$target").XXXXXX")
      $coreutils/bin/cp "$source" "$temporary"
      $coreutils/bin/chmod 0644 "$temporary"
      $coreutils/bin/mv -f "$temporary" "$target"
      temporary=""
    }

    prune_old_generations() {
      [ -s "$generation_list" ] || {
        echo "error: refusing to prune generations because the selected generation list is empty" >&2
        exit 1
      }
      for old in "$target_data"/nixos-generation-*.efi; do
        [ -e "$old" ] || continue
        old_name=$($coreutils/bin/basename "$old")
        old_generation=''${old_name#nixos-generation-}
        old_generation=''${old_generation%.efi}
        if ! $grep -qx "$old_generation" "$generation_list"; then
          $coreutils/bin/rm -f "$old"
        fi
      done
    }

    cfg_tmp="$tmp_root/grub.cfg"
    {
      echo 'set timeout=5'
      echo 'set default=0'
      if [ -n "$current_generation" ]; then
        echo "menuentry 'NixOS current (generation $current_generation)' {"
      else
        echo "menuentry 'NixOS current' {"
      fi
      echo '  set root='
      echo '  search --no-floppy --file --set=root /EFI/NixOS/raw-os/nixos-current.efi'
      echo '  if [ -n "$root" ]; then'
      echo '    chainloader ($root)/EFI/NixOS/raw-os/nixos-current.efi'
      echo '  else'
      echo "    echo 'NixOS current EFI was not found'"
      echo '    sleep 3'
      echo '  fi'
      echo '}'
      while read -r generation; do
        [ -n "$generation" ] || continue
        [ "$generation" = "$current_generation" ] && continue
        echo "menuentry 'NixOS generation $generation' {"
        echo '  set root='
        echo '  search --no-floppy --file --set=root /EFI/NixOS/raw-os/nixos-generation-'"$generation"'.efi'
        echo '  if [ -n "$root" ]; then'
        echo '    chainloader ($root)/EFI/NixOS/raw-os/nixos-generation-'"$generation"'.efi'
        echo '  else'
        echo "    echo 'NixOS generation $generation was not found'"
        echo '    sleep 3'
        echo '  fi'
        echo '}'
      done < <($coreutils/bin/sort -rn "$generation_list")
      $coreutils/bin/cat <<'WINDOWS_ENTRY'
    menuentry 'Windows Boot Manager' {
      set windows=
      search --no-floppy --file --set=windows /EFI/Microsoft/Boot/bootmgfw.efi
      if [ -n "$windows" ]; then
        set root="$windows"
        chainloader ($root)/EFI/Microsoft/Boot/bootmgfw.efi
      else
        echo 'Windows Boot Manager was not found'
        sleep 3
      fi
    }
    WINDOWS_ENTRY
    } > "$cfg_tmp"

    $coreutils/bin/mkdir -p "$boot_mount/EFI/BOOT" "$target_data"
    prune_old_generations
    install_file "$tmp_root/nixos-current.efi" "$target_data/nixos-current.efi"
    while read -r generation; do
      [ -n "$generation" ] || continue
      install_file "$tmp_root/nixos-generation-$generation.efi" "$target_data/nixos-generation-$generation.efi"
    done < "$generation_list"
    install_file "$cfg_tmp" "$target_data/grub.cfg"
    prune_old_generations
    install_file "${rawOsBootEfi}" "$boot_mount/EFI/BOOT/BOOTX64.EFI"
    $coreutils/bin/sync
    echo "updated: /boot/EFI/BOOT/BOOTX64.EFI"
    echo "updated: /boot/EFI/NixOS/raw-os/grub.cfg"
    echo "toplevel: $toplevel"
  '';

in
{
  imports = [
    (modulesPath + "/profiles/minimal.nix")
  ];

  system.build.rawOsBootEfi = rawOsBootEfi;
  system.build.rawOsBootConfig = rawOsGrubConfig;
  system.build.rawOsExternalBootEfi = rawOsExternalBootEfi;

  boot.loader.external = {
    enable = true;
    installHook = installRawBoot;
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
          dbg "done"
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
  services.getty.autologinUser = "nixos";

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

  environment.sessionVariables.PATH = [
    "/run/current-system/sw/bin"
    "/run/current-system/sw/sbin"
    "/usr/local/bin"
    "/usr/bin"
    "/bin"
  ];
  environment.systemPackages = with pkgs; [
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
