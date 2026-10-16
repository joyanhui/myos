{
  pkgs,
  username,
  ...
}:
{
  home-manager.users.${username} =
    { ... }:
    {
      home.packages = [ pkgs.zellij ];

      xdg.configFile."zellij/config.kdl".text = ''
        mouse_mode true
        copy_clipboard "system"
        copy_on_select true
      '';
    };
}
