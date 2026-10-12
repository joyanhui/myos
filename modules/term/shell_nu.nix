{
  pkgs,
  username,
  ...
}:
{
  home-manager = {
    users.${username} = {
      home.packages = with pkgs; [
        nushell
      ];
      home.file = {
        ".config/nushell/config.nu".text = ''
          $env.config.shell_integration.osc133 = false
          $env.config.show_banner = false
        '';
      };
    };
  };
}
