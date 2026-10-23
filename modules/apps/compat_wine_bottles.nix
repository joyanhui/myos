{
  lib,
  pkgs,
  username,
  ...
}:
let
  pkgsNoOpenldapCheck = pkgs.extend (
    final: prev: {
      openldap = prev.openldap.overrideAttrs (_: {
        doCheck = false;
      });
    }
  );

  bottlesGuideText = ''
    本机 Bottles 预设指南
    =================================

    本模块存在的原因
    - Bottles 安装时会一并提供 32 位图形支持，这通常是 NixOS 上运行旧 Win32 软件所缺少的关键依赖。
    - 同时安装了 winetricks 和 cabextract，以便在某个 bottle 需要额外字体或运行时库时手动修复依赖。

    推荐的 bottle 类型
    1. 旧版 32 位软件
    - 创建新 bottle 时选择：
      环境：Custom
      架构：win32
      Windows 版本：Windows 7
    - 除非程序明确需要 DirectX 转换，否则保持 DXVK/VKD3D 关闭。
    - 适用于 XP/Win7 时代的工具、安装程序、启动器、编辑器以及许多旧版实用程序。

    2. 普通办公 / 标准 Windows 软件
    - 创建新 bottle 时选择：
      环境：Application
      架构：win64
      Windows 版本：Windows 10
    - 仅在安装程序明确要求时才安装额外依赖。
    - 适用于较规范的软件、办公工具、常见安装程序和主流 Win10 应用。

    实用的首次运行清单
    - 重建系统后先打开一次 Bottles，让其完成初始运行器/组件的设置。
    - 运行大型安装程序前，在 bottle 内创建还原点。
    - 如果中文显示乱码，尝试在该 bottle 中安装 corefonts 或应用所需的字体。
    - 如果安装程序提示缺少 .NET 或 VC 运行时，请通过 Bottles 添加依赖，而不是修改全局 Wine 设置。
    - 如果旧版应用在 Wayland 下出现渲染问题，先尝试在配置为旧软件的 bottle 中运行。

    本模块安装的辅助命令
    - bottles-open-guide
    - bottles-new-legacy32 <名称>
    - bottles-new-standard <名称>
  '';

  bottlesOpenGuide = pkgs.writeShellScriptBin "bottles-open-guide" ''
    set -eu
    guide="$HOME/.local/share/bottles/os_joyanhui-guide.md"

    if [ ! -r "$guide" ]; then
      printf '%s\n' "Guide not found: $guide" >&2
      exit 1
    fi

    if command -v bat >/dev/null 2>&1; then
      exec bat --paging=never --style=plain "$guide"
    fi

    exec cat "$guide"
  '';

  bottlesNewLegacy32 = pkgs.writeShellScriptBin "bottles-new-legacy32" ''
    set -eu
    name="''${1:-legacy32}"

    if ! command -v bottles-cli >/dev/null 2>&1; then
      printf '%s\n' "bottles-cli is not available on PATH. Open Bottles once or create the bottle manually using bottles-open-guide." >&2
      exit 1
    fi

    bottles-cli new --bottle-name "$name" --environment custom --arch win32
    bottles-cli edit -b "$name" --win win7

    printf '%s\n' "Created bottle '$name' (custom, win32, Windows 7)."
    printf '%s\n' "Next step: open Bottles and add dependencies only if the installer actually requires them."
  '';

  bottlesNewStandard = pkgs.writeShellScriptBin "bottles-new-standard" ''
    set -eu
    name="''${1:-standard-win64}"

    if ! command -v bottles-cli >/dev/null 2>&1; then
      printf '%s\n' "bottles-cli is not available on PATH. Open Bottles once or create the bottle manually using bottles-open-guide." >&2
      exit 1
    fi

    bottles-cli new --bottle-name "$name" --environment application --arch win64
    bottles-cli edit -b "$name" --win win10

    printf '%s\n' "Created bottle '$name' (application, win64, Windows 10)."
    printf '%s\n' "Next step: only add .NET / VC runtime dependencies when the installer explicitly asks for them."
  '';

  bottleCompat = lib.hiPrio (
    pkgs.writeShellScriptBin "bottle" ''
      exec bottles "$@"
    ''
  );
in
{
  hardware.graphics.enable32Bit = true;

  home-manager.users.${username} = {
    home.packages = [
      bottleCompat
      pkgsNoOpenldapCheck.bottles.override { removeWarningPopup = true; }
      pkgs.winetricks
      pkgs.cabextract
      bottlesOpenGuide
      bottlesNewLegacy32
      bottlesNewStandard
    ];

    home.file = {
      ".local/share/bottles/os_joyanhui-guide.md".text = bottlesGuideText;
    };
  };
}
