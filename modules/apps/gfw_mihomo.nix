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

    配置文件: ${global_settings.secretsDir}/mihomo.yaml
    外部控制器: 0.0.0.0:9090

    UI可用：pkgs.metacubexd 在无法打开的时候，应该是包更新导致的浏览器缓存紊乱。解决办法是F12 network 勾选 disable cache
  '';
  standaloneReadme = ''
    Mihomo Web UI 访问方式:
       本地: http://127.0.0.1:9090/ui/
       线上: https://metacubex.github.io/metacubexd

    配置文件: ~/.config/mihomo/config.yaml (由 ${global_settings.secretsDir}/mihomo.yaml 生成，TUN 已关闭)
    外部控制器: 0.0.0.0:9090
    HTTP 代理端口: 7890
  '';
  rawConfig = builtins.readFile "${global_settings.secretRelDir}/mihomo.yaml";
  noTunConfig = lib.replaceStrings [ "tun:\n  enable: true" ] [ "tun:\n  enable: false" ] rawConfig;
in
if hmStandalone then
  {
    home.packages = [ pkgs.mihomo ];

    xdg.configFile."mihomo/config.yaml".text = noTunConfig;

    xdg.configFile."mihomo/README.md".text = standaloneReadme;

    systemd.user.services.mihomo = {
      Unit.Description = "Mihomo proxy (user-level, no TUN)";
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.mihomo}/bin/mihomo -f ${config.home.homeDirectory}/.config/mihomo/config.yaml -d ${config.home.homeDirectory}/.config/mihomo";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "default.target" ];
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

    environment.systemPackages = with pkgs; [ mihomo ];

    home-manager = {
      users.${username} = { ... }: {
        home.packages = with pkgs; [ mihomo ];
        home.file.".config/mihomo/README.md".text = readme;
      };
    };
  }
