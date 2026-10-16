{ ... }:

{
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
