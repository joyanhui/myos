{
  pkgs,
  username,
  lib,
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
        autosuggestion = {
          enable = true;
          highlight = "fg=#6272a4";
        };
        syntaxHighlighting = {
          enable = true;
          styles = {
            command = "fg=#98be65";
            builtin = "fg=#98be65";
            function = "fg=#98be65";
            alias = "fg=#98be65";
            unknown-token = "fg=#ff6c6b";
            redirection = "fg=#ff9e64";
            comment = "fg=#6272a4";
            single-quoted-argument = "fg=#a9b1d6";
            double-quoted-argument = "fg=#a9b1d6";
            path = "fg=#7dcfff";
            globbing = "fg=#bb9af7";
          };
        };
        historySubstringSearch.enable = true;
        history = {
          size = 10000;
          save = 10000;
          append = true;
          share = true;
        };
        initContent = lib.mkAfter ''
          autoload -Uz vcs_info add-zsh-hook
          zstyle ':vcs_info:git:*' formats ' %F{yellow}[%b]%f'
          add-zsh-hook precmd vcs_info
          setopt prompt_subst
          PROMPT='%F{green}%n%f@%F{cyan}%m%f %F{blue}%~%f''${vcs_info_msg_0_} %(?.%F{green}.%F{red})❯%f '
          RPROMPT='%F{cyan}%D{%H:%M:%S}%f'
        '';
        shellAliases = commonAliases // { };
      };
    };
}
