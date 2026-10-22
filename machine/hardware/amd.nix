{ pkgs, ... }:

{
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
