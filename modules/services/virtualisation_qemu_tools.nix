{ pkgs
, ...
}:
{
  environment.systemPackages = with pkgs; [
    qemu
    cdrkit
    debootstrap
  ];
}
