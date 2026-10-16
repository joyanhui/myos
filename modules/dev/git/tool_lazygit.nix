{
  pkgs,
  username,
  ...
}:
{
  home-manager = {
    users.${username} = {
      home.packages = with pkgs; [
        lazygit
      ];

      xdg.configFile."lazygit/config.yml".text = ''
                gui:
                  editor: hx
                  nerdFontsVersion: "3"
                  showRandomTip: false
                  showCommandLog: false
                  parseEmoji: true
                  theme:
                    activeBorderColor:
                      - green
                      - bold
                    selectedLineBgColor:
                      - default
                os:
                  editCommand: hx
                  editCommandTemplate: hx {{filename}}
                confirmOnQuit: true

      '';
    };
  };
}
