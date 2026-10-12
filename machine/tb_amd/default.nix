{ pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  swapDevices = [
    {
      device = "/swapfile";
    }
  ];

  environment.systemPackages = with pkgs; [
    amdgpu_top
    amdctl
    swayidle
  ];

  boot = {
    tmp.cleanOnBoot = true;
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [
      "amd_iommu=on"
      "iommu=pt"
      "consoleblank=600"
    ];
    kernelModules = [ "kvm-amd" ];
    initrd.kernelModules = [
      "amdgpu"
      "vfio"
      "vfio_iommu_type1"
      "vfio_pci"
    ];
    extraModprobeConfig = ''
      options kvm_amd nested=1
      options bt_coex_active=0 swcrypto=1 11n_disable=8
      options kvm ignore_msrs=1 report_ignored_msrs=0
    '';
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

  services.logind.settings.Login = {
    IdleAction = "suspend";
    IdleActionSec = "45min";
  };

  services.printing.enable = true;

  systemd.services.ucsi-rebind = {
    description = "Rebind ucsi_acpi to work around PPM init timeout on Lenovo ThinkBook";
    after = [ "sysinit.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      sleep 20
      echo "USBC000:00" > /sys/bus/platform/drivers/ucsi_acpi/unbind 2>/dev/null || true
      sleep 1
      echo "USBC000:00" > /sys/bus/platform/drivers/ucsi_acpi/bind 2>/dev/null || true
    '';
  };
}
