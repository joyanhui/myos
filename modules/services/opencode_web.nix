{
  pkgs,
  username,
  ...
}:
let
  userHome = "/home/${username}";
  opencodeBin = "${userHome}/.bun/bin/opencode";
  opencodeConfigDir = "${userHome}/.config/opencode";
in
{
  systemd.services.opencode_web = {
    description = "OpenCode web service";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = with pkgs; [
      bash
      coreutils
      git
    ];
    environment = {
      HOME = userHome;
      XDG_CONFIG_HOME = "${userHome}/.config";
    };
    serviceConfig = {
      Type = "simple";
      User = username;
      WorkingDirectory = opencodeConfigDir;
      ExecStart = "${opencodeBin} web --port 19900 --hostname 0.0.0.0";
      Restart = "on-failure";
      RestartSec = 5;
      KillSignal = "SIGKILL";
      KillMode = "control-group";
    };
  };
}
