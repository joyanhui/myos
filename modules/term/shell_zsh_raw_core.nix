{ pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    promptInit = "";
    interactiveShellInit = ''
      source ${pkgs.zsh-autosuggestions}/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
      source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    '';
  };

  users.users.nixos.shell = pkgs.zsh;
}
