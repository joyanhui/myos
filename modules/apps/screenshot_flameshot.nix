{
  pkgs,
  username,
  ...
}:
{
  home-manager = {
    users.${username} = {
      home.packages = with pkgs; [
        flameshot
      ];

      xdg.configFile."flameshot/flameshot.ini" = {
        text = ''
          [General]
          useGrimAdapter=true
        '';
      };
    };
  };
}
