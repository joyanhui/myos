{ username, lib, ... }:
{
  home-manager.users.${username}.programs.bash.initExtra = lib.mkAfter ''
    if [[ $- == *i* ]] && [ -z "$FISH_ACTIVE" ] && [ -t 0 ] && command -v fish >/dev/null 2>&1; then
        export FISH_ACTIVE=1
        fish
    fi
  '';
}