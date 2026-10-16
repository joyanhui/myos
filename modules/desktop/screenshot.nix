{
  pkgs,
  username,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    grim
    slurp
    grimblast
    wf-recorder
    cliphist
    ksnip
    swappy
    xdg-desktop-portal-wlr
  ];

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
