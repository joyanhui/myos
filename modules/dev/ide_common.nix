{
  pkgs,
  username,
  ...
}:
{
  home-manager = {
    users.${username} = {
      home.packages = with pkgs; [
        prettier
        universal-ctags
        delta
        gitlint
      ];
    };
  };
}
