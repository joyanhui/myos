{
  pkgs,
  username,
  ...
}:
{

  home-manager = {
    users.${username} = {
      home.packages = with pkgs; [
        keepassxc
        (makeDesktopItem {
          name = "brave-private";
          desktopName = "Brave Web Browser";
          genericName = "Open a private Brave window";
          icon = "brave";
          exec = "${brave}/bin/brave --incognito";
          categories = [ "Network" ];
        })

      ];
      programs.brave = {
        enable = true;
        package = pkgs.brave;
        extensions = [
          { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; }
          #          { id = "oboonakemofpalcgghocfoadofidjkkk"; } # keepassxc
          #          { id = "pnidmkljnhbjfffciajlcpeldoljnidn"; } # linkwarden
          { id = "nngceckbapebfimnlniiiahkandclblb"; }
          { id = "fnaicdffflnofjppbagibeoednhnbjhg"; }
          { id = "ffjiejobkoibkjlhjnlgmcnnigeelbdl"; }
          { id = "jlgkpaicikihijadgifklkbpdajbkhjo"; }
          # { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # uBlock Origin
          { id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; }
          #  { id = "iaddfgegjgjelgkanamleadckkpnjpjc"; } # Auto Quality for YouTube
          # { id = "annfbnbieaamhaimclajlajpijgkdblo"; } # Dark Theme
          # { id = "hlepfoohegkhhmjieoechaddaejaokhf"; } # Refined Github 优化了几个界面
          { id = "bggfcpfjbdkhfhfmkjpbhnkhnpjjeomc"; }
          # { id = "cbghhgpcnddeihccjmnadmkaejncjndb"; } # Vencord web 阻止 Discord 的跟踪等等！
          # { id = "ghmbeldphafepmbegfdlkpapadhbakde"; } # proton pass  密码管理器 收费版支持 MFA和 2FA
          #{ id = "mnjggcdmjocbbbhaepdhchncahnbgone"; } # sponsorblock yt 跳过赞助商广告 主要 youtube
          #  {id = "jiaopdjbehhjgokpphdfgmapkobbnmjp";} # shorts block yt 允许 YouTube 短片视频在常规页面上播放。
          #   {id = "pkehgijcmpdhfbdbbnkijodmdjhbjlgp";} # privacy badger 隐私獾
        ];
        commandLineArgs = [
          #       "--password-store=gnome-libsecret"
          #      "--enable-accelerated-video-decode"
          #     "--disable-features=WaylandWpColorManagerV1"
          # "--ozone-platform=wayland"
          "--password-store=basic"
          "--proxy-server=http://127.0.0.1:7890"
        ];

      };

    };
  };

}
