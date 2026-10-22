{
  inputs,
  pkgs,
  lib,
  global_settings,
  ...
}:
{
  imports = [ inputs.nixos-wsl.nixosModules.default ];
  # imports = [ nixos-wsl.nixosModules.default ];

  wsl.defaultUser = global_settings.username;
  wsl.enable = true;
  users.allowNoPasswordLogin = true;

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

  swapDevices = [ ];

  systemd.services.systemd-binfmt.serviceConfig.SuccessExitStatus = "1";

  system.activationScripts.binTrue = lib.stringAfter [ "binsh" ] ''
    ln -sfn ${pkgs.coreutils}/bin/true /bin/true
  '';

  systemd.services.wsl-vgem = {
    description = "Load vgem (WSLg GPU render node /dev/dri)";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.runtimeShell} -c '${pkgs.kmod}/bin/modprobe vgem || true'";
    };
  };
}
