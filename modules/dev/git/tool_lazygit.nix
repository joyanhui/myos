{
  pkgs,
  username,
  lib,
  ...
}:
let
  commitTypes = import ./commit_prefix_list.nix;

  yamlOptions = lib.concatStringsSep "\n" (
    lib.concatMap (t: [
      "                  - name: \"${t.prefix}\""
      "                    description: \"${t.description}\""
      "                    value: \"${t.prefix}\""
    ]) commitTypes
  );
in
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

                customCommands:
                  - key: "C"
                    context: "files"
                    description: "交互式提交（选择 Conventional Commits 前缀）"
                    prompts:
                      - type: "menu"
                        title: "选择提交类型 (Conventional Commits)"
                        key: "CommitType"
                        options:
        ${yamlOptions}
                      - type: "input"
                        title: "输入提交描述"
                        key: "Message"
                    command: "git commit -m \"{{.Form.CommitType}}: {{.Form.Message}}\""
                    loadingText: "提交中..."
                    output: terminal
      '';
    };
  };
}
