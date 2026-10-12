{
  pkgs,
  username,
  global_settings,
  ...
}:
let
  font = global_settings.font;
  bg = "#1A0F0A";
  fg = "#E0D0E0";
in
{
  home-manager = {
    users.${username} = {
      home.packages = with pkgs; [ vte ];

      xdg.configFile."gtk-3.0/vte-2.91.css".text = ''
        /* vte-2.91 终端全局配色 */
        /* 暖紫黑底配色 */

        @define-color background ${bg};
        @define-color foreground ${fg};

        /* 8 标准色 */
        @define-color color0  #1E1A1E;
        @define-color color1  #D05A6A;
        @define-color color2  #6AB06A;
        @define-color color3  #D0A040;
        @define-color color4  #6080C0;
        @define-color color5  #B070B0;
        @define-color color6  #40A0A0;
        @define-color color7  #E8D8E8;

        /* 8 亮色 */
        @define-color color8  #4A3A4A;
        @define-color color9  #F07A8A;
        @define-color color10 #8AD08A;
        @define-color color11 #F0C060;
        @define-color color12 #80A0E0;
        @define-color color13 #D090D0;
        @define-color color14 #60C0C0;
        @define-color color15 #F0E0F0;

        /* VTE 终端样式 */
        VteTerminal,
        TerminalScreen,
        vte-terminal {
            background-color: @background;
            color: @foreground;
            -vteterminal-background-opacity: 0.85;
        }

        /* 选中样式 */
        VteTerminal:selected,
        TerminalScreen:selected {
            background-color: #3A2A3A;
            color: @foreground;
        }
      '';
    };
  };
}
