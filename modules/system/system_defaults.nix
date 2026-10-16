{ global_settings, ... }:
let
  stateVersion = global_settings.stateVersion;
in
{
  documentation.nixos.enable = false;
  system.stateVersion = stateVersion;
  time.timeZone = "Asia/Shanghai";
  systemd.settings.Manager.RebootWatchdogSec = "10s";
  systemd.services.dbus-broker = {
    serviceConfig.TimeoutStartSec = 180;
  };
}
