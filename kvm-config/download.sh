#!/usr/bin/env bash
# ==============================================================================
# download.sh — 通用下载 / 解压 / 转换工具
#
# 用法:
#   download.sh -u <URL> -o <OUTPUT> [选项]
#
# 必填:
#   -u, --url URL        下载地址
#   -o, --output PATH    最终文件路径
#
# 可选:
#   -a, --archive PATH   压缩包保存路径（默认由 output 推导）
#   -e, --extract TYPE   解压方式: zip|gz|7z|xz|auto（默认 auto，按后缀判断）
#   -c, --convert TYPE   转换格式: qcow2|vmdk（默认由 output 后缀自动判断）
#   -k, --keep           保留压缩包（默认删除）
#   -y, --yes            静默覆盖
#   --help               显示此帮助
# ==============================================================================

set -euo pipefail

URL=""
OUTPUT=""
ARCHIVE=""
EXTRACT="auto"
CONVERT="auto"
KEEP=0
YES=0

usage() {
    sed -n '3,18p' "$0"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -u|--url)       URL="$2";  shift 2 ;;
        -o|--output)    OUTPUT="$2"; shift 2 ;;
        -a|--archive)   ARCHIVE="$2"; shift 2 ;;
        -e|--extract)   EXTRACT="$2"; shift 2 ;;
        -c|--convert)   CONVERT="$2"; shift 2 ;;
        -k|--keep)      KEEP=1;   shift ;;
        -y|--yes)       YES=1;    shift ;;
        --help)         usage ;;
        *) echo "未知参数: $1" >&2; usage ;;
    esac
done

[[ -z "$URL" || -z "$OUTPUT" ]] && { usage >&2; exit 1; }

OUTPUT_DIR="$(dirname "$OUTPUT")"
mkdir -p "$OUTPUT_DIR"

OUTPUT_BASENAME="$(basename "$OUTPUT")"
OUTPUT_EXT="${OUTPUT_BASENAME##*.}"

if [[ -z "$ARCHIVE" ]]; then
    case "$URL" in
        *.zip)  ARCHIVE="${OUTPUT_DIR}/$(basename "$URL")" ;;
        *.7z)   ARCHIVE="${OUTPUT_DIR}/$(basename "$URL")" ;;
        *.tar.gz|*.tgz) ARCHIVE="${OUTPUT_DIR}/$(basename "$URL")" ;;
        *.gz)   ARCHIVE="${OUTPUT_DIR}/$(basename "$URL")" ;;
        *.xz)   ARCHIVE="${OUTPUT_DIR}/$(basename "$URL")" ;;
        *)      ARCHIVE="$OUTPUT" ;;
    esac
fi

ARCHIVE_BASENAME="$(basename "$ARCHIVE")"
if [[ "$EXTRACT" == "auto" ]]; then
    case "$ARCHIVE" in
        *.zip)          EXTRACT="zip" ;;
        *.tar.gz|*.tgz) EXTRACT="tar.gz" ;;
        *.gz)           EXTRACT="gz" ;;
        *.7z)           EXTRACT="7z" ;;
        *.xz)           EXTRACT="xz" ;;
        *)              EXTRACT="none" ;;
    esac
fi

if [[ "$CONVERT" == "auto" ]]; then
    case "$OUTPUT_EXT" in
        qcow2|vmdk) CONVERT="$OUTPUT_EXT" ;;
        *)          CONVERT="none" ;;
    esac
fi

if [[ -f "$OUTPUT" && "$YES" -eq 0 ]]; then
    read -r -p "文件已存在: $OUTPUT，覆盖？[y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || exit 0
fi

WORKDIR="$(mktemp -d)"
cleanup() {
    rm -rf "$WORKDIR"
}
trap cleanup EXIT

echo "==> 下载: $URL"
wget -c -O "$ARCHIVE" "$URL"

if [[ "$EXTRACT" == "none" && "$CONVERT" == "none" ]]; then
    if [[ "$ARCHIVE" != "$OUTPUT" ]]; then
        mv "$ARCHIVE" "$OUTPUT"
    fi
    echo "==> 完成: $OUTPUT"
    exit 0
fi

EXTRACTED=""
case "$EXTRACT" in
    zip)
        echo "==> 解压 (zip): $ARCHIVE"
        unzip -o "$ARCHIVE" -d "$WORKDIR" >/dev/null 2>&1
        for f in "$WORKDIR"/*; do
            if [[ -f "$f" ]]; then
                EXTRACTED="$f"
                break
            fi
        done
        ;;
    gz)
        echo "==> 解压 (gz): $ARCHIVE"
        gunzip -k "$ARCHIVE" --stdout > "$WORKDIR/extracted.img" || true
        EXTRACTED="$WORKDIR/extracted.img"
        ;;
    tar.gz)
        echo "==> 解压 (tar.gz): $ARCHIVE"
        tar -xzf "$ARCHIVE" -C "$WORKDIR" || true
        for f in "$WORKDIR"/*; do
            if [[ -f "$f" ]]; then
                EXTRACTED="$f"
                break
            fi
        done
        ;;
    7z)
        echo "==> 解压 (7z): $ARCHIVE"
        7z x "$ARCHIVE" -o"$WORKDIR" -y >/dev/null 2>&1 || true
        for f in "$WORKDIR"/*; do
            if [[ -f "$f" ]]; then
                EXTRACTED="$f"
                break
            fi
        done
        ;;
    xz)
        echo "==> 解压 (xz): $ARCHIVE"
        unxz -k "$ARCHIVE" --stdout > "$WORKDIR/extracted.img" || true
        EXTRACTED="$WORKDIR/extracted.img"
        ;;
    none)
        EXTRACTED="$ARCHIVE"
        ;;
esac

if [[ -z "$EXTRACTED" || ! -f "$EXTRACTED" ]]; then
    echo "错误: 解压后未找到有效文件" >&2
    exit 1
fi

if [[ "$CONVERT" != "none" ]]; then
    echo "==> 转换: $(basename "$EXTRACTED") → $CONVERT"
    case "$CONVERT" in
        qcow2) qemu-img convert -f raw -O qcow2 "$EXTRACTED" "$OUTPUT" ;;
        vmdk)  qemu-img convert -f raw -O vmdk  "$EXTRACTED" "$OUTPUT" ;;
        *) echo "错误: 不支持的转换格式: $CONVERT" >&2; exit 1 ;;
    esac
else
    if [[ "$EXTRACTED" != "$OUTPUT" ]]; then
        mv "$EXTRACTED" "$OUTPUT"
    fi
fi

echo "==> 完成: $OUTPUT"

[[ "$KEEP" -eq 0 ]] && rm -f "$ARCHIVE"
