{
  pkgs,
  username,
  ...
}:
let
  brave = pkgs.callPackage (
    {
      lib,
      stdenv,
      fetchurl,
      dpkg,
      wrapGAppsHook3,
      alsa-lib,
      at-spi2-atk,
      at-spi2-core,
      atk,
      cairo,
      cups,
      dbus,
      expat,
      fontconfig,
      freetype,
      gdk-pixbuf,
      glib,
      adwaita-icon-theme,
      gsettings-desktop-schemas,
      gtk3,
      gtk4,
      qt6,
      libx11,
      libxscrnsaver,
      libxcomposite,
      libxcursor,
      libxdamage,
      libxext,
      libxfixes,
      libxi,
      libxrandr,
      libxrender,
      libxshmfence,
      libxtst,
      libdrm,
      libkrb5,
      libuuid,
      libxkbcommon,
      libgbm,
      libpulseaudio,
      libva,
      libxcb,
      libGL,
      nspr,
      nss,
      pango,
      pciutils,
      pipewire,
      snappy,
      speechd-minimal,
      udev,
      vulkan-loader,
      wayland,
      xdg-utils,
      coreutils,
      zenity,
      zlib,
      commandLineArgs ? "",
    }:
    let
      version = "1.99.55";
      optName = "brave";
      fileBase = "brave-browser";
      appId = "com.brave.Browser";
      innerWrapper = "brave-browser";
      upstreamBin = "brave-browser-stable";

      deps = [
        alsa-lib
        at-spi2-atk
        at-spi2-core
        atk
        cairo
        cups
        dbus
        expat
        fontconfig
        freetype
        gdk-pixbuf
        glib
        gtk3
        gtk4
        libdrm
        libx11
        libGL
        libxkbcommon
        libxscrnsaver
        libxcomposite
        libxcursor
        libxdamage
        libxext
        libxfixes
        libxi
        libxrandr
        libxrender
        libxshmfence
        libxtst
        libuuid
        libgbm
        nspr
        nss
        pango
        pciutils
        pipewire
        udev
        wayland
        libxcb
        zlib
        snappy
        speechd-minimal
        libkrb5
        vulkan-loader
        qt6.qtbase
        libpulseaudio
        libva
      ];

      rpath = lib.makeLibraryPath deps + ":" + lib.makeSearchPathOutput "lib" "lib64" deps;
      binpath = lib.makeBinPath deps;
    in
    stdenv.mkDerivation {
      pname = "brave";
      inherit version;

      src = fetchurl {
        url = "https://github.com/brave/brave-browser/releases/download/v${version}/brave-browser_${version}_amd64.deb";
        hash = "sha256-Nk6VSirYTVuj4OIXoinVhzxK5xB9FeYSDkIHUpU5yI0=";
      };

      nativeBuildInputs = [
        dpkg
        wrapGAppsHook3
      ];

      buildInputs = [
        glib
        gsettings-desktop-schemas
        gtk3
        gtk4
        adwaita-icon-theme
      ];

      unpackPhase = ''
        dpkg-deb --fsys-tarfile $src | tar --extract
      '';

      dontConfigure = true;
      dontBuild = true;
      dontPatchELF = true;
      dontStrip = true;

      installPhase = ''
        runHook preInstall

        mkdir -p $out $out/bin

        cp -R usr/share $out
        cp -R opt/ $out/opt

        export BINARYWRAPPER=$out/opt/brave.com/${optName}/${innerWrapper}

        substituteInPlace $BINARYWRAPPER \
            --replace-fail /bin/bash ${stdenv.shell} \
            --replace-fail 'CHROME_WRAPPER' 'WRAPPER'

        ln -sf $BINARYWRAPPER $out/bin/${optName}

        for exe in $out/opt/brave.com/${optName}/{brave,chrome_crashpad_handler}; do
            patchelf \
                --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
                --set-rpath "${rpath}" $exe
        done

        for desktop in $out/share/applications/*.desktop; do
            substituteInPlace $desktop \
                --replace-fail /usr/bin/${upstreamBin} $out/bin/${optName}
        done

        if [ -e $out/share/gnome-control-center/default-apps/${fileBase}.xml ]; then
            substituteInPlace $out/share/gnome-control-center/default-apps/${fileBase}.xml \
                --replace-fail /opt/brave.com $out/opt/brave.com
        fi

        if [ -e $out/opt/brave.com/${optName}/default-app-block ]; then
            substituteInPlace $out/opt/brave.com/${optName}/default-app-block \
                --replace-fail /opt/brave.com $out/opt/brave.com
        fi

        for icon in 16 24 32 48 64 128 256; do
            if [ -e $out/opt/brave.com/${optName}/product_logo_''${icon}.png ]; then
                mkdir -p $out/share/icons/hicolor/''${icon}x''${icon}/apps
                ln -sf $out/opt/brave.com/${optName}/product_logo_''${icon}.png \
                    $out/share/icons/hicolor/''${icon}x''${icon}/apps/${fileBase}.png
            fi
        done

        if [ -e $out/opt/brave.com/${optName}/libvulkan.so.1 ]; then
            rm $out/opt/brave.com/${optName}/libvulkan.so.1
            ln -s ${lib.getLib vulkan-loader}/lib/libvulkan.so.1 \
                $out/opt/brave.com/${optName}/libvulkan.so.1
        fi

        ln -sf ${xdg-utils}/bin/xdg-settings $out/opt/brave.com/${optName}/xdg-settings
        ln -sf ${xdg-utils}/bin/xdg-mime $out/opt/brave.com/${optName}/xdg-mime

        runHook postInstall
      '';

      preFixup = ''
        gappsWrapperArgs+=(
          --prefix LD_LIBRARY_PATH : ${rpath}
          --prefix PATH : ${binpath}
          --suffix PATH : ${lib.makeBinPath [ xdg-utils coreutils zenity ]}
          --set CHROME_WRAPPER ${optName}
          --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto}}"
          --add-flags ${lib.escapeShellArg commandLineArgs}
        )
      '';

      meta = {
        homepage = "https://brave.com/";
        description = "Privacy-oriented browser for Desktop and Laptop computers";
        sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
        license = lib.licenses.mpl20;
        platforms = [ "x86_64-linux" ];
        mainProgram = "brave";
      };
    }
  ) { };
in
{

  home-manager = {
    users.${username} = {
      home.packages = with pkgs; [
        keepassxc
        zenity
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
        package = brave;
        extensions = [
          #          { id = "oboonakemofpalcgghocfoadofidjkkk"; } # keepassxc
          #          { id = "pnidmkljnhbjfffciajlcpeldoljnidn"; } # linkwarden
          { id = "nngceckbapebfimnlniiiahkandclblb"; } # Bitwarden
          { id = "fnaicdffflnofjppbagibeoednhnbjhg"; } # floccus
          { id = "ffjiejobkoibkjlhjnlgmcnnigeelbdl"; } # CookieCloud
          { id = "fnldhkfidchnjiokpoemdhoejmaojkgp"; } # FlowMouse
          # { id = "jlgkpaicikihijadgifklkbpdajbkhjo"; } crxMouse
          # { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # uBlock Origin
          { id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; } # darkreader
          #  { id = "iaddfgegjgjelgkanamleadckkpnjpjc"; } # Auto Quality for YouTube
          # { id = "annfbnbieaamhaimclajlajpijgkdblo"; } # Dark Theme
          # { id = "hlepfoohegkhhmjieoechaddaejaokhf"; } # Refined Github 优化了几个界面
          { id = "bggfcpfjbdkhfhfmkjpbhnkhnpjjeomc"; } # Material Icons for GitHub
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
