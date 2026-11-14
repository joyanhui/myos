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
        confirmOnQuit: true

      '';
    };
  };
}
