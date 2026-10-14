{
  pkgs,
  username,
  ...
}:
let
  inherit (import ./shell_common_aliases.nix) commonAliases;
in
{
  programs.zsh.enable = true;
  environment.pathsToLink = [ "/share/zsh" ];

  home-manager.users.${username} =
    { ... }:
    {
      home.packages = with pkgs; [
        zsh
        zsh-completions
      ];

      programs.zsh = {
        enable = true;
        enableCompletion = true;
        autosuggestion.enable = true;
        historySubstringSearch.enable = true;
        history = {
          size = 10000;
          save = 10000;
          append = true;
          share = true;
        };
        shellAliases = commonAliases // { };
      };
    };
}
