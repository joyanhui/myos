{
  pkgs,
  config,
  hmStandalone ? false,
  ...
}:
if hmStandalone then
  {
    home.packages = with pkgs; [ grc ];

    xdg.configFile."grc/grc.conf".source = "${pkgs.grc}/etc/grc.conf";

    home.sessionVariables.GRC_CONFIG = "${config.home.homeDirectory}/.config/grc/grc.conf";
  }
else
  {
    environment.systemPackages = with pkgs; [ grc ];
    environment.etc."grc.conf".source = "${pkgs.grc}/etc/grc.conf";
  }