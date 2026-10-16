{
  pkgs,
  lib,
  moduleTags,
  global_settings,
  ...
}:
let
  moduleLib = import ./module_list_lib.nix { inherit lib moduleTags; };
  importIf = moduleLib.importIf;
  hasTag = moduleLib.hasTag;
in
{
  imports =
    [ ]

    ++ importIf (hasTag "wsl") {
      environment.variables.PATH = lib.mkForce [ "$PATH" ];
      wsl.wslConf.network.generateResolvConf = lib.mkDefault false;
      wsl.interop.register = lib.mkDefault true;
      networking.wireless.enable = lib.mkForce false;
      networking.networkmanager.wifi.backend = lib.mkForce "iwd";
      systemd.tmpfiles.rules = [
        "d /tmp/.X11-unix 1777 root root -"
      ];
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };
      services.power-profiles-daemon.enable = lib.mkForce false;
      hardware.i2c.enable = lib.mkForce false;
    }

    ++ importIf (hasTag "common") ./modules/system/env_manager.nix
    ++ importIf (hasTag "desktop") ./modules/system/env_manager_wayland.nix
    ++ importIf (hasTag "wsl") ./modules/system/env_manager_wsl.nix
    ++ importIf (hasTag "common") ./modules/system/home_user_config.nix
    ++ importIf (hasTag "common") ./modules/system/networking_firewall_config.nix
    ++ importIf (hasTag "common") ./modules/system/nixpkgs_system.nix
    ++ importIf (hasTag "common") ./modules/system/zram.nix
    ++ importIf (hasTag "wsl") ./modules/system/swap_zram_wsl.nix
    ++ importIf (hasTag "common") ./modules/services/openssh.nix
    ++ importIf (hasTag "common") ./modules/services/cron.nix
    ++ importIf (hasTag "common") ./modules/term/shell_bash.nix
    ++ importIf (hasTag "common") ./modules/term/shell_fish.nix
    ++ importIf (hasTag "common") ./modules/term/shell_zsh.nix
    ++ importIf (hasTag "dev") ./modules/term/shell_nu.nix
    ++ importIf (hasTag "common") ./modules/dev/git/git_fiash_fun.nix
    ++ importIf (hasTag "common") (
      import "${global_settings.secretRelDir}/openssh_auth_keys_and_passwd.nix"
    )
    ++ importIf (hasTag "common") (import "${global_settings.secretRelDir}/sensitive_env.nix")

    ++ importIf (hasTag "physical") ./modules/system/wifi.nix
    ++ importIf (hasTag "physical") ./modules/services/bluetooth.nix
    ++ importIf (hasTag "physical") ./modules/services/mnt_autofs.nix
    ++ importIf (hasTag "physical") ./modules/apps/recovery_testdisk.nix
    ++ importIf (hasTag "raw-amd") {
      environment.systemPackages = with pkgs; [
        amdgpu_top
        amdctl
      ];
      boot.kernelParams = [
        "amd_iommu=on"
        "iommu=pt"
      ];
      boot.kernelModules = [ "kvm-amd" ];
      boot.initrd.kernelModules = [
        "amdgpu"
        "vfio"
        "vfio_iommu_type1"
        "vfio_pci"
      ];
      boot.extraModprobeConfig = ''
        options kvm_amd nested=1
        options kvm ignore_msrs=1 report_ignored_msrs=0
      '';
    }
    ++ importIf (hasTag "raw-intel") {
      boot.kernelParams = [
        "intel_iommu=on"
        "iommu=pt"
      ];
      boot.kernelModules = [ "kvm-intel" ];
      boot.initrd.kernelModules = [
        "i915"
        "vfio"
        "vfio_iommu_type1"
        "vfio_pci"
      ];
      boot.extraModprobeConfig = ''
        options kvm_intel nested=1
        options kvm ignore_msrs=1 report_ignored_msrs=0
      '';
    }
    ++ importIf (hasTag "common") ./modules/apps/fastfetch.nix

    ++ importIf (hasTag "inputKeyd") ./modules/services/input_keyd.nix

    ++ importIf (hasTag "desktop") ./modules/desktop/swaylock.nix
    ++ importIf (hasTag "desktop") ./modules/desktop/wayland_wm_base.nix
    ++ importIf (hasTag "wsl" || hasTag "desktop") ./modules/desktop/wayland_rofi.nix
    ++ importIf (hasTag "wsl" || hasTag "desktop") ./modules/desktop/wayland_wm_niri.nix
    ++ importIf ((hasTag "wsl" || hasTag "desktop")) ./modules/desktop/wayland_dms.nix
    ++ importIf (hasTag "desktop") ./modules/desktop/wayland_screenshot.nix
    # ++ importIf (hasTag "desktop") ./modules/system/desktopfile_manager.nix

    ++ importIf (hasTag "gui" || hasTag "wsl") ./modules/system/theme.nix
    ++ importIf (hasTag "gui") ./modules/system/xdg_mimes.nix
    ++ importIf (hasTag "gui") ./modules/services/sound_pipewire.nix

    ++ importIf (hasTag "dev") ./modules/system/font_i18n.nix
    ++ importIf (hasTag "dev") ./modules/system/nix_ld.nix
    ++ importIf (hasTag "dev") ./modules/term/term_kitty.nix
    ++ importIf (hasTag "dev" && !hasTag "wsl") ./modules/term/term_vte.nix
    ++ importIf (hasTag "dev") ./modules/term/term_ghostty.nix
    ++ importIf (hasTag "dev") ./modules/term/tool_grc.nix
    ++ importIf (hasTag "dev") ./modules/term/tool_xclip.nix
    ++ importIf (hasTag "dev") ./modules/apps/filemanager_yazi.nix
    ++ importIf (hasTag "dev") ./modules/apps/compat_appimage.nix
    ++ importIf (hasTag "dev") ./modules/apps/rclone_kopia.nix
    ++ importIf (hasTag "dev" && !hasTag "wsl") ./modules/apps/gfw_mihomo.nix
    ++ importIf (hasTag "dev") ./modules/dev/git/git_github_gitea.nix
    ++ importIf (hasTag "dev") ./modules/dev/git/git-auto-commit-skill.nix
    ++ importIf (hasTag "dev") ./modules/dev/dev_base_and_import_all.nix
    ++ importIf (hasTag "editor") ./modules/dev/dev_editor_extras.nix

    ++ importIf (hasTag "editor") ./modules/dev/ide_helix.nix
    # ++ importIf (hasTag "editor" && !hasTag "wsl") ./modules/dev/ide_antigravity.nix
    ++ importIf (hasTag "editor" && !hasTag "wsl") ./modules/dev/ide_thonny.nix
    ++ importIf (hasTag "editor") ./modules/dev/ide_common.nix
    ++ importIf (hasTag "editor") ./modules/dev/git/tool_lazygit.nix

    ++ importIf (hasTag "input-method") ./modules/input-method/fcitx5_rime.nix
    ++ importIf (hasTag "wsl") ./modules/input-method/fcitx5_rime_wsl.nix
    ++ importIf (hasTag "input-method") ./modules/input-method/voxtype.nix

    ++ importIf (hasTag "dailyPC") ./modules/apps/filemanager_thunar.nix
    ++ importIf (hasTag "dailyPC") ./modules/apps/screenshot_flameshot.nix
    ++ importIf (hasTag "dailyPC") ./modules/apps/graphics_gimp3.nix
    ++ importIf (hasTag "dailyPC") ./modules/apps/browser/brave.nix
    #++ importIf (hasTag "dailyPC") ./modules/apps/browser/chromium.nix
    #++ importIf (hasTag "dev") ./modules/apps/browser/firefox.nix
    #./modules/apps/browser/free_download_manager.nix
    ++ importIf (hasTag "dailyPC") ./modules/apps/browser/google_chrome.nix
    ++ importIf (hasTag "dailyPC" || hasTag "wsl") ./modules/apps/office_obsidian.nix
    #++ importIf (hasTag "dailyPC") ./modules/apps/office_wps.nix
    # ++ importIf (hasTag "dailyPC") ./modules/apps/im/qq.nix
    ++ importIf (hasTag "dailyPC") ./modules/apps/im/telegram.nix
    ++ importIf (hasTag "dailyPC") ./modules/apps/im/wechat.nix
    # ++ importIf (hasTag "dailyPC") ./modules/apps/im/wechat_devtools.nix
    ## ++ importIf (hasTag "dailyPC") ./modules/apps/android_mobile_connect.nix
    #++ importIf (hasTag "dailyPC") ./modules/apps/compat_wine_bottles.nix
    # ++ importIf (hasTag "dailyPC") ./modules/apps/download_motrix.nix
    ++ importIf (hasTag "dailyPC") ./modules/apps/media_vlc.nix
    ++ importIf (hasTag "dailyPC") ./modules/apps/music_musicfree.nix
    # ++ importIf (hasTag "dailyPC") ./modules/apps/office_trilium_next_desktop.nix
    #++ importIf (hasTag "services") ./modules/apps/pkg_nginx.nix
    # ./modules/apps/remote_todesk.nix
    ++ importIf (hasTag "dailyPC") ./modules/services/virtualisation_kvm_libvirtd.nix
    ## ++ importIf (hasTag "dailyPC") ./modules/services/virtualisation_waydroid.nix
    # ./modules/services/xrdp.nix
    # ++ importIf (hasTag "dailyPC") ./modules/services/remote_sunshine.nix
    # ./modules/services/share_samba.nix
    # ++ importIf (hasTag "dailyPC") ./modules/services/virtualisation_virtualbox.nix
    # ++ importIf (hasTag "dailyPC") ./modules/services/virtualisation_vbox_serv.nix
    ++ importIf (hasTag "services") ./modules/services/virtualisation_docker.nix
    ++ importIf (hasTag "wsl") ./modules/services/virtualisation_qemu_tools.nix

    # ++ importIf (hasTag "services") ./modules/services/db_postgresql.nix
    # ++ importIf (hasTag "services") ./modules/services/db_valkey.nix
    ++ importIf (hasTag "services") ./modules/services/dev_db_tools.nix
    # ++ importIf (hasTag "services") ./modules/services/opencode_web.nix
    #  ++ importIf (hasTag "desktop") ./modules/services/pkg_flatpak.nix
    ++ importIf (hasTag "ai") ./modules/ai/ai_common.nix
  # ++ importIf (hasTag "ai" && !hasTag "wsl") ./modules/ai/cc_switch.nix
  # ++ importIf (hasTag "ai") ./modules/ai/chatgpt_gui_cli.nix
  # ++ importIf (hasTag "ai") ./modules/ai/ollama_llama_cpp.nix
  ;

  environment.systemPackages =
    with pkgs;
    [
      coreutils-full
      expect
      psmisc
      iftop
      fd
      htop
      jq
      dos2unix
      tree
      unzip
      p7zip
      unrar
      wget
      curl
      bat
      ttyd
      inetutils
      pciutils
      usbutils
      dig
      dnslookup
      doggo
      knot-dns
      direnv

      dosfstools
      exfat
      btrfs-progs
      btrfs-snap
      ntfs3g
      davfs2
      fuse3
    ]
    ++ lib.optionals (hasTag "gui") [
      dex
      imv
      libnotify
      viewnior
      bleachbit
    ];
}
