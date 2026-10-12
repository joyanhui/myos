{
  lib,
  pkgs,
  username,
  ...
}:

let
  pname = "wechat-devtools";
  version = "2.02.2608060";
  upstreamRev = "1f29b81d30d542f92509f56b0831f04839dcbe40";

  upstreamSrc = pkgs.fetchFromGitHub {
    owner = "msojocs";
    repo = "wechat-web-devtools-linux";
    rev = upstreamRev;
    hash = "sha256-GTvlrT+gXTzQasjtiE3D31A+mqNSqoTN07kSu5tdxNI=";
  };

  devtoolsExe = pkgs.fetchurl {
    url = "https://devtools.wxqcloud.qq.com.cn/WechatWebDev/release/be1ec64cf6184b0fa64091919793f068/wechat_devtools_2.02.2608060_win32_x64.exe";
    hash = "sha256-aDGkmNQbL+cWwcVMc2zEqEEiOK7t1cl8grbQ7L6q9H0=";
  };

  electronZip = pkgs.fetchurl {
    url = "https://github.com/electron/electron/releases/download/v36.6.0/electron-v36.6.0-linux-x64.zip";
    hash = "sha256-ag3ss+OC8y1Ks9uQqr0ILvnuEVT+IFgI+IfiKP2y01U=";
  };

  nodeDist = pkgs.fetchurl {
    url = "https://npmmirror.com/mirrors/node/v22.16.0/node-v22.16.0-linux-x64.tar.gz";
    hash = "sha256-+4cCJhGdRzePqcksRTU4nHLa4U/Me0fm/cyCxD3lpUc=";
  };

  ripgrep = pkgs.fetchurl {
    url = "https://github.com/microsoft/ripgrep-prebuilt/releases/download/v15.0.0/ripgrep-v15.0.0-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-ndkwaixEzdox4vTzzzb01xSCYNk3FoPpZdPImSwgU0k=";
  };

  floatPigment = pkgs.fetchurl {
    url = "https://github.com/msojocs/float-pigment-rust/releases/download/continuous/float-pigment.linux-x64-gnu.node";
    hash = "sha256-A7ipWEYvUnNTWpqWAQntjb8NSfkrPW3MkMIa4ULgVK0=";
  };

  wcc = pkgs.fetchurl {
    url = "https://github.com/msojocs/wx-compiler/releases/download/v0.1.7/wcc-x86_64";
    hash = "sha256-yR2YN4WfxWIFjxxCOgVs3iBnwB+drU50eB2mCc+YgV0=";
  };
  wcsc = pkgs.fetchurl {
    url = "https://github.com/msojocs/wx-compiler/releases/download/v0.1.7/wcsc-x86_64";
    hash = "sha256-fKcvuC3yG2xrzF+6zIgJzjDciFK2/jvcXjNxbKUegao=";
  };
  wccNode = pkgs.fetchurl {
    url = "https://github.com/msojocs/wx-compiler/releases/download/v0.1.7/wcc-x86_64.node";
    hash = "sha256-creU26/ACSaeb+m4rPh+1CrxD6tP4iAHwKUAoU6MPxM=";
  };
  wcscNode = pkgs.fetchurl {
    url = "https://github.com/msojocs/wx-compiler/releases/download/v0.1.7/wcsc-x86_64.node";
    hash = "sha256-2/7X/tB2TRjbW8gvYP6gdDc+bsjopb0IwXXXNOJMzFY=";
  };

  wechatDevtoolsBuild = pkgs.stdenv.mkDerivation {
    inherit pname version;
    src = upstreamSrc;

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-J2ZX5Mt+ZxQiNDjA07OMQ4DrVN65yp3r/bmX5gJdFys=";

    nativeBuildInputs = with pkgs; [
      bash
      p7zip
      unzip
      wget
      git
      nodejs_22
      node-gyp
      gcc
      gnumake
      python3
      perl
      pkg-config
      asar
      gawk
      gnused
      coreutils
      findutils
    ];

    buildInputs = with pkgs; [
      krb5
      libssh2
      openssl
      zlib
      libx11
      libxkbfile
      libxtst
      libxext
      glibc.dev
    ];

    configurePhase = ''
      runHook preConfigure
      cp -r $src/* ./
      chmod -R u+w .
      patchShebangs tools bin 2>/dev/null || true
      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild

      export PATH="$PWD/electron:$PWD/tools:$PATH"
      export HOME="$TMPDIR/home"
      mkdir -p "$HOME"
      mkdir -p cache
      cp ${devtoolsExe} cache/wechat_devtools_2.02.2608060_x64.exe
      cp ${electronZip} cache/electron-v36.6.0-linux-x64.zip
      cp ${nodeDist} cache/node-v22.16.0-linux-x64.tar.gz
      cp ${ripgrep} cache/ripgrep-v15.0.0-x86_64-unknown-linux-musl.tar.gz
      cp ${floatPigment} cache/float-pigment-continuous.node
      mkdir -p cache/compiler/v0.1.7
      cp ${wcc} cache/compiler/v0.1.7/wcc-x86_64
      cp ${wcsc} cache/compiler/v0.1.7/wcsc-x86_64
      cp ${wccNode} cache/compiler/v0.1.7/wcc-x86_64.node
      cp ${wcscNode} cache/compiler/v0.1.7/wcsc-x86_64.node
      chmod +x cache/compiler/v0.1.7/*

      mkdir -p electron
      unzip -q ${electronZip} -d electron/

      mkdir -p tmp/devtools
      7z x cache/wechat_devtools_2.02.2608060_x64.exe -otmp/devtools resources -y >/dev/null
      mv tmp/devtools/resources ./resources

      echo "0" > resources/.build_time

      mkdir -p tmp
      echo -n "INSTALL_REBUILD_SUCCESS" > tmp/.step

      export PATH="$PWD/cache/npm/node_global/bin:$PATH"

      mkdir -p "$HOME/bin"
      printf '#!/bin/sh\nexec %s "$@"\n' "$(command -v env)" > "$HOME/bin/env"
      chmod +x "$HOME/bin/env"
      export PATH="$HOME/bin:$PATH"

      sed -i 's|npx asar|asar|g' tools/asar-helper.sh

      sed -i 's|--inspect=9229 ||' bin/wechat-devtools

      sed -i 's|^echo $timeStamp > "''${package_dir}/.build_time"|echo 0 > "''${package_dir}/.build_time"|' tools/fix-other.sh
      sed -i 's|^ *echo $timeStamp > "''${package_dir}/.build_time"|  echo 0 > "''${package_dir}/.build_time"|' tools/fix-core.sh
      sed -i 's|^echo "$timestamp" > "$root_dir/resources/.build_time"|echo "0" > "$root_dir/resources/.build_time"|' tools/update-wechat-devtools.sh

      bash tools/setup-wechat-devtools.sh version=${version}

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r bin electron resources $out/
      runHook postInstall
    '';

    postFixup = ''
      find $out -type f \( -name '*.sh' -o -path '*/bin/*' -o -path '*/.bin/*' \) \
        -exec sed -i '1s|^#!.*/nix/store/.*|#!/usr/bin/env bash|' {} + 2>/dev/null || true
      sed -i '1s|^#!.*|#!/usr/bin/env bash|' $out/bin/* 2>/dev/null || true
    '';
  };

  steamRun = (pkgs.steam.override {
    extraPkgs = pkgs: with pkgs; [
      nss
      libxshmfence
      libsecret
      libxkbfile
    ];
  }).run;

  nodeDir = pkgs.runCommand "wechat-devtools-node" {} ''
    mkdir -p $out/node/bin $out/electron
    ln -s ${pkgs.nodejs_22}/bin/node $out/node/bin/node
    ln -s ${pkgs.nodejs_22}/bin/npm $out/node/bin/npm
    ln -s ${pkgs.nodejs_22}/bin/npx $out/node/bin/npx
    ln -s ${pkgs.nodejs_22}/bin/node $out/electron/node
    ln -s node $out/electron/node.exe
    ln -s node $out/electron/node-18.exe
  '';

  wechatDevtoolsComplete = pkgs.symlinkJoin {
    name = "${pname}-complete-${version}";
    paths = [ wechatDevtoolsBuild nodeDir ];
  };

  wechatDevtoolsLauncher = pkgs.writeShellScriptBin pname ''
    if [ -z "$XDG_CONFIG_HOME" ]; then
      data_dir="$HOME/.config"
    else
      data_dir="$XDG_CONFIG_HOME"
    fi
    mkdir -p "$data_dir/wechat-devtools"
    export WECHAT_DEVTOOLS_DIR="${wechatDevtoolsComplete}/electron"
    export APPDATA="$data_dir/wechat-devtools/app"
    export USERPROFILE="$APPDATA"
    export PATH="${wechatDevtoolsComplete}/node/bin:${wechatDevtoolsComplete}/electron:$PATH"
    mkdir -p "$APPDATA"
    exec ${steamRun}/bin/steam-run ${wechatDevtoolsComplete}/electron/electron \
      --no-sandbox ${wechatDevtoolsComplete}/resources/app.asar "$@"
  '';

  wechatDevtoolsCli = pkgs.writeShellScriptBin "wechat-devtools-cli" ''
    if [ -z "$XDG_CONFIG_HOME" ]; then
      data_dir="$HOME/.config"
    else
      data_dir="$XDG_CONFIG_HOME"
    fi
    export WECHAT_DEVTOOLS_DIR="${wechatDevtoolsComplete}/electron"
    export APPDATA="$data_dir/wechat-devtools"
    export USERPROFILE="$APPDATA"
    mkdir -p "$APPDATA/Default"
    exec ${steamRun}/bin/steam-run ${wechatDevtoolsComplete}/electron/node \
      ${wechatDevtoolsComplete}/resources/app.asar.unpacked/js/common/cli/index.js "$@"
  '';

  wechatDevtools = pkgs.symlinkJoin {
    name = "${pname}-${version}";
    paths = [ wechatDevtoolsLauncher wechatDevtoolsCli ];
    postBuild = ''
      mkdir -p $out/share/applications
      cat > $out/share/applications/wechat-devtools.desktop <<DESKTOP_EOF
[Desktop Entry]
Name=WeChat DevTools
Name[zh_CN]=微信开发者工具
Comment=WeChat Mini Program DevTools
Exec=wechat-devtools
Icon=wechat-devtools
Type=Application
Categories=Development;
Terminal=false
StartupWMClass=wechat-devtools
DESKTOP_EOF
      mkdir -p $out/share/icons/hicolor/512x512/apps
      cp ${upstreamSrc}/res/icons/256x256.png $out/share/icons/hicolor/512x512/apps/wechat-devtools.png 2>/dev/null || true
    '';
    meta = {
      description = "Linux version of the WeChat Mini Program DevTools";
      homepage = "https://github.com/msojocs/wechat-web-devtools-linux";
      license = lib.licenses.unfree;
      platforms = [ "x86_64-linux" ];
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      mainProgram = pname;
    };
  };
in
{
  home-manager.users.${username} = {
    home.packages = [
      wechatDevtools
      wechatDevtoolsCli
    ];
  };

  passthru = {
    inherit wechatDevtoolsBuild wechatDevtools wechatDevtoolsCli;
  };
}
