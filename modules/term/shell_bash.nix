{
  pkgs,
  username,
  config,
  lib,
  ...
}:
let
  inherit (import ./shell_common_aliases.nix) commonAliases;
in
{
  programs.bash = {
    completion.enable = true;
    shellAliases = commonAliases // {};
  };

  home-manager = {
    users.${username} =
      { config, lib, ... }:
      {
        home.packages = with pkgs; [
          bash
        ];
        programs.bash = {
          enable = true;
          enableCompletion = true;
          historySize = 10000;
          historyFileSize = 10000;
          initExtra = ''
            unset __HM_SESS_VARS_SOURCED
            [ -f ~/.profile ] && . ~/.profile

            export GRC_ALIASES=true
            source ${pkgs.grc}/etc/profile.d/grc.sh
          '';
        };
      };
  };

}
