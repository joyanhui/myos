{
  pkgs,
  username,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    swaylock-effects
  ];

  home-manager.users.${username} =
    { ... }:
    {
      xdg.configFile."swaylock/config".text = ''
        screenshot
        scaling=fill

        color=1e1e2e
        effect-blur=30x12

        inside-color=313244
        ring-color=b07cd8

        inside-clear-color=313244
        ring-clear-color=89b4fa

        inside-ver-color=313244
        ring-ver-color=a6e3a1

        inside-wrong-color=313244
        ring-wrong-color=f38ba8

        key-hl-color=74c7ec
        bs-hl-color=f38ba8

        line-color=1e1e2e
        separator-color=6c7086

        text-color=cdd6f4
        text-clear-color=89b4fa
        text-ver-color=a6e3a1
        text-wrong-color=f38ba8
        indicator-radius=220
        indicator-thickness=14

        fade-in=0.3
        grace=0
        grace-no-mouse
        indicator-idle-visible
        clock
      '';
    };
}
