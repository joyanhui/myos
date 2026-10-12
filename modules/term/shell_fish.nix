{
  pkgs,
  inputs,
  username,
  global_settings,
  ...
}:
let
  inherit (import ./shell_common_aliases.nix) commonAliases;
in
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  documentation.man.cache.enable = true;
  documentation.man.cache.generateAtRuntime = true;

  home-manager = {
    users.${username} = { config, lib, ... }: {
      home.packages = with pkgs; [
        fish
        fishPlugins.bass
        fishPlugins.grc
      ];

      xdg.configFile."fish/functions/bass.fish".source =
        "${pkgs.fishPlugins.bass}/share/fish/vendor_functions.d/bass.fish";
      xdg.configFile."fish/functions/__bass.py".source =
        "${pkgs.fishPlugins.bass}/share/fish/vendor_functions.d/__bass.py";
      xdg.configFile."fish/functions/grc.wrap.fish".source =
        "${pkgs.fishPlugins.grc}/share/fish/vendor_functions.d/grc.wrap.fish";
      xdg.configFile."fish/conf.d/grc.fish".source =
        config.lib.file.mkOutOfStoreSymlink "${global_settings.repoDir}/modules/term/term_grc.fish";
      xdg.configFile."fish/conf.d/executables".source =
        "${pkgs.fishPlugins.grc}/share/fish/vendor_conf.d/executables";

      programs.fish = {
        enable = true;
        generateCompletions = false;

        interactiveShellInit = ''
          set -x FISH_ACTIVE 1

          if set -q __FISH_DEVSHELL
            set fish_color_normal    '#f7768e'
            set fish_color_command   '#f7768e'
            set fish_color_param     '#ff9e64'
            set fish_color_error     '#ff007c'
            set fish_color_autosuggestion '#565f89'
          else
            set fish_color_normal    '#98be65'
            set fish_color_command   '#98be65'
            set fish_color_param     '#98be65'
            set fish_color_error     '#ff6c6b'
            set fish_color_autosuggestion '#6272a4'
          end
          set fish_greeting

          function fish_prompt
            set -l last_status ''$status

            if set -q __FISH_DEVSHELL
              set_color blue
              echo -n '[DEV] '
              set_color red
              echo -n (whoami)
              set_color normal
              echo -n '@'
              set_color magenta
              echo -n (hostname -s)
              set_color normal

              set_color magenta
              echo -n ':'(prompt_pwd)
              set_color normal

              set_color yellow
              fish_vcs_prompt 2>/dev/null | string trim
              set_color normal

              if test ''$last_status -ne 0
                set_color red
                echo -n " [''$last_status]"
                set_color normal
              end

              echo
              set_color red
              echo -n '❯ '
              set_color normal
            else
              set_color green
              echo -n (whoami)
              set_color normal
              echo -n '@'
              set_color cyan
              echo -n (hostname -s)
              set_color normal

              set_color blue
              echo -n ':'(prompt_pwd)
              set_color normal

              set_color yellow
              fish_vcs_prompt 2>/dev/null | string trim
              set_color normal

              if test ''$last_status -ne 0
                set_color red
                echo -n " [''$last_status]"
                set_color normal
              end

              echo
              set_color green
              echo -n '➤ '
              set_color normal
            end

            return ''$last_status
          end

          function fish_right_prompt
            if set -q __FISH_DEVSHELL
              set_color magenta
              echo -n '(dev)'
              set_color normal
              date '+%H:%M:%S'
            else
              set_color cyan
              echo -n '(°))< 🐟'
              set_color normal
              date '+%H:%M:%S'
            end
          end
        '';

        shellAliases = commonAliases // {
          helix = "hx";
          neofetch = "echo fastfetch && fastfetch";
        };
      };

      programs.man.generateCaches = false;

      systemd.user.services.fish-update-completions = {
        Unit.Description = "Regenerate manpage-based fish completions";
        Service = {
          Type = "oneshot";
          Nice = 19;
          ExecStart = "${pkgs.fish}/bin/fish -c fish_update_completions";
        };
      };

      systemd.user.timers.fish-update-completions = {
        Unit.Description = "Periodically regenerate manpage-based fish completions";
        Timer = {
          OnCalendar = "weekly";
          Persistent = true;
          RandomizedDelaySec = "15min";
        };
        Install.WantedBy = [ "timers.target" ];
      };

    };
  };

}
