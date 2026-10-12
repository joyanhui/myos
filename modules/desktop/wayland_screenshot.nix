{
  pkgs,
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
}