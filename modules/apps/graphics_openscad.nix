{
  pkgs,
  username,
  ...
}:
{
  home-manager = {
    users.${username} =
      { config, ... }:
      {
        home.packages = with pkgs; [
          openscad-unstable
          openscad-lsp
        ];
      };
  };
}
