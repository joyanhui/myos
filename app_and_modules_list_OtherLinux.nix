{
  pkgs,
  lib,
  username,
  moduleTags,
  global_settings,
  inputs,
  ...
}:
let
  moduleLib = import ./module_list_lib.nix { inherit lib moduleTags; };
  importIf = moduleLib.importIf;
  hasTag = moduleLib.hasTag;
  extract = file:
    let
      mod = (import file) {
        inherit pkgs lib username moduleTags global_settings inputs;
        config = { };
      };
    in
    mod.home-manager.users.${username} or { };
in
{
  imports =
    [ ]

    ++ importIf (hasTag "common") (extract ./modules/system/env_manager.nix)
    ++ importIf (hasTag "common") (extract ./modules/system/home_user_config.nix)
    ++ importIf (hasTag "common") (extract ./modules/term/shell_bash.nix)
    ++ importIf (hasTag "common") (extract ./modules/term/shell_fish.nix)
    ++ importIf (hasTag "common") (extract ./modules/term/shell_zsh.nix)
    ++ importIf (hasTag "common") (extract "${global_settings.secretRelDir}/sensitive_env.nix")
    ++ importIf (hasTag "common") ./modules/term/tool_grc.nix

    ++ importIf (hasTag "dev") (extract ./modules/system/xdg_mimes.nix)
    ++ importIf (hasTag "dev") (extract ./modules/dev/git/git_github_gitea.nix)
    ++ importIf (hasTag "dev") (extract ./modules/dev/git/git_fiash_fun.nix)
    ++ importIf (hasTag "dev") (extract ./modules/apps/rclone_kopia.nix)
    ++ importIf (hasTag "dev") (extract ./modules/apps/filemanager_yazi.nix)
    ++ importIf (hasTag "dev") (extract ./modules/term/term_kitty.nix)
    ++ importIf (hasTag "dev") (extract ./modules/term/term_ghostty.nix)
    ++ importIf (hasTag "dev") (extract ./modules/term/term_vte.nix)
    ++ importIf (hasTag "dev") (extract ./modules/term/tool_xclip.nix)
    ++ importIf (hasTag "dev") ./modules/system/font_i18n.nix
    ++ importIf (hasTag "dev") ./modules/apps/gfw_mihomo.nix
    ++ importIf (hasTag "dev") ./modules/dev/dev_base_and_import_all.nix
    ++ importIf (hasTag "editor") ./modules/dev/dev_editor_extras.nix

    ++ importIf (hasTag "editor") (extract ./modules/dev/ide_helix.nix)
    ++ importIf (hasTag "editor") (extract ./modules/dev/ide_common.nix)
    ++ importIf (hasTag "editor") (extract ./modules/dev/git/tool_lazygit.nix)

    ++ importIf (hasTag "ai") (extract ./modules/ai/ai_common.nix)
    ++ importIf (hasTag "ai") (extract ./modules/ai/cc_switch.nix)
    ++ importIf (hasTag "ai") (extract ./modules/ai/chatgpt_gui_cli.nix)

    ++ importIf (hasTag "input-method") (extract ./modules/input-method/voxtype.nix)
    ++ importIf (hasTag "input-method") ./modules/input-method/fcitx5_rime.nix

    ++ importIf (hasTag "gui") (extract ./modules/system/theme.nix)

    ++ importIf (hasTag "dailyPC") (extract ./modules/apps/browser/brave.nix)
    ++ importIf (hasTag "dailyPC") (extract ./modules/apps/browser/google_chrome.nix)
    ++ importIf (hasTag "dailyPC") (extract ./modules/apps/im/telegram.nix)
    ++ importIf (hasTag "dailyPC") (extract ./modules/apps/im/wechat.nix)
    ++ importIf (hasTag "dailyPC") (extract ./modules/apps/media_vlc.nix)
    ++ importIf (hasTag "dailyPC") (extract ./modules/apps/music_musicfree.nix)
    ++ importIf (hasTag "dailyPC") (extract ./modules/apps/office_obsidian.nix)
    ++ importIf (hasTag "dailyPC") (extract ./modules/apps/filemanager_thunar.nix)
    ++ importIf (hasTag "dailyPC") (extract ./modules/apps/screenshot_flameshot.nix)
    ++ importIf (hasTag "dailyPC") (extract ./modules/apps/graphics_gimp3.nix)
  ;
}