{
  pkgs,
  username,
  ...
}:
let
  inherit (pkgs) yaziPlugins;
in
{
  home-manager = {
    users.${username} = {
      programs.yazi = {
        enable = true;

        enableFishIntegration = true;
        enableBashIntegration = true;

        extraPackages = with pkgs; [
          file
          ripgrep
          fd
          bat
          chafa
          poppler-utils
          ffmpegthumbnailer
          p7zip
          lazygit
        ];

        plugins = {
          lazygit = {
            package = yaziPlugins.lazygit;
            setup = false;
          };
          clipboard = {
            package = yaziPlugins.clipboard;
            setup = false;
          };
          full-border = {
            package = yaziPlugins.full-border;
            setup = true;
          };
          mount = {
            package = yaziPlugins.mount;
            setup = false;
          };
        };

        settings = {
          manager = {
            ratio = [
              1
              4
              3
            ];
            show_hidden = true;
            sort_dir_first = true;
          };
          preview = {
            max_width = 600;
            max_height = 900;
            cache_dir = "/tmp/yazi-cache";
          };
          opener = {
            edit = [
              {
                run = ''nvim "$@"'';
                block = true;
              }
            ];
            open = [
              {
                run = ''xdg-open "$@"'';
                block = false;
              }
            ];
            reveal = [
              {
                run = ''thunar "$(dirname "$@")"'';
                block = false;
                desc = "在 Thunar 中打开";
              }
            ];
          };
          clipboard = {
            import = [
              {
                name = "wl-clipboard";
                run = "wl-copy";
                raw = true;
              }
              {
                name = "wl-clipboard";
                run = "wl-paste";
                raw = true;
              }
            ];
          };
          open.rules = [
            {
              url = "*.txt";
              use = "edit";
            }
            {
              url = "*.md";
              use = "edit";
            }
            {
              url = "*.nix";
              use = "edit";
            }
            {
              url = "*.rs";
              use = "edit";
            }
            {
              url = "*.toml";
              use = "edit";
            }
          ];
          plugin.prepend_previewers = [
            {
              mime = "video/*";
              run = "ffmpegthumbnailer";
            }
          ];
        };

        theme = {
          status.separators = "rounded";

          which.sort = "alphabetical";
        };

        keymap = {
          manager.prepend_keymap = [
            {
              on = [
                "g"
                "l"
              ];
              run = "plugin lazygit";
              desc = "Lazygit";
            }
            {
              on = [
                "g"
                "m"
              ];
              run = "plugin mount";
              desc = "挂载管理";
            }
          ];
        };
      };
    };
  };
}
