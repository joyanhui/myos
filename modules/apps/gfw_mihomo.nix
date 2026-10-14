{
  pkgs,
  lib,
  config,
  username,
  global_settings,
  hmStandalone ? false,
  ...
}:

let
  readme = ''
    Mihomo Web UI 访问方式:
       本地: http://127.0.0.1:9090/ui/
       线上: https://metacubex.github.io/metacubexd

    配置文件:
       NixOS: ${global_settings.secretsDir}/mihomo.yaml
       standalone: ~/.config/mihomo/config.yaml (由 ${global_settings.secretsDir}/mihomo.yaml 生成，并自动关闭TUN)
    外部控制器: 0.0.0.0:9090
    HTTP 代理端口: 7890

    UI可用：pkgs.metacubexd 在无法打开的时候，应该是包更新导致的浏览器缓存紊乱。解决办法是F12 network 勾选 disable cache

    为了避免紊乱，本服务只安装不会自动启动，请手动启动。
  '';
  rawConfig = builtins.readFile "${global_settings.secretRelDir}/mihomo.yaml";
  noTunConfig = lib.replaceStrings [ "tun:\n  enable: true" ] [ "tun:\n  enable: false" ] rawConfig;
in
if hmStandalone then
  {
    home.packages = [ pkgs.mihomo ];

    xdg.configFile."mihomo/config.yaml".text = noTunConfig;

    xdg.configFile."mihomo/README.md".text = readme;

    systemd.user.services.mihomo = {
      Unit.Description = "Mihomo proxy (user-level, no TUN)";
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.mihomo}/bin/mihomo -f ${config.home.homeDirectory}/.config/mihomo/config.yaml -d ${config.home.homeDirectory}/.config/mihomo";
        Restart = "on-failure";
      };
      Install.WantedBy = [ ];
    };
  }
else
  {
    services.mihomo = {
      enable = true;
      tunMode = true;
      webui = pkgs.metacubexd;
      configFile = "${global_settings.secretsDir}/mihomo.yaml";
    };

    systemd.services.mihomo.wantedBy = lib.mkForce [ ];

    environment.systemPackages = with pkgs; [ mihomo ];

    home-manager = {
      users.${username} = { ... }: {
        home.packages = with pkgs; [ mihomo ];
        home.file.".config/mihomo/README.md".text = readme;
      };
    };
  }
