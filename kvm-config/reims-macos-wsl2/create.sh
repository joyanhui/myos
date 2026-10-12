#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VM_DIR="${MACOS_VM_DIR:-/home/nixos/vdisks/macos}"
BOARD_ID="${MACOS_BOARD_ID:-Mac-4B682C642B45593E}"
DISK_SIZE="${MACOS_DISK_SIZE:-128G}"
OSXKVM_RAW="${MACOS_OSXKVM_RAW:-https://raw.githubusercontent.com/kholia/OSX-KVM/master}"
RECOVERY_HOST="osrecovery.apple.com"
ASSET_HOST="oscdn.apple.com"

for tool in curl openssl python3 qemu-img; do
    command -v "$tool" >/dev/null || { echo "missing tool: $tool" >&2; exit 1; }
done

mkdir -p "$VM_DIR"
cd "$VM_DIR"

fetch_data() {
    local url="$1" out="$2"
    curl -fL -o "$out" "$url"
}

fetch_token_asset() {
    local url="$1" token="$2" out="$3"
    curl -fL -H "User-Agent: InternetRecovery/1.0" -H "Cookie: AssetToken=$token" -o "$out" "$url"
}

recovery_info() {
    local session body
    session="$(curl -s -D - -o /dev/null "http://$RECOVERY_HOST/" | tr -d '\r' \
        | awk -F'session=' '/^[Ss]et-[Cc]ookie: session=/{split($2,c,";"); print "session=" c[1]}')"
    [ -n "$session" ] || { echo "no recovery session" >&2; exit 1; }
    body="$(printf 'cid=%s\nsn=%s\nbid=%s\nk=%s\nfg=%s\nos=%s\n' \
        "$(openssl rand -hex 8 | tr 'a-f' 'A-F')" \
        "00000000000000000" \
        "$BOARD_ID" \
        "$(openssl rand -hex 32 | tr 'a-f' 'A-F')" \
        "$(openssl rand -hex 32 | tr 'a-f' 'A-F')" \
        "latest")"
    curl -s -m 60 -H "Host: $RECOVERY_HOST" -H "Connection: close" \
        -H "User-Agent: InternetRecovery/1.0" -H "Cookie: $session" \
        -H "Content-Type: text/plain" --data "$body" \
        "http://$RECOVERY_HOST/InstallationPayload/RecoveryImage"
}

dmg_to_raw() {
    python3 - "$1" "$2" <<'PY'
import bz2
import plistlib
import struct
import sys
import zlib

HEADER_SIZE = 204
RUN_SIZE = 40
ZERO_TYPES = (0, 2, 0xFFFFFFFF)


def convert(src, dst):
    with open(src, "rb") as f:
        f.seek(-512, 2)
        koly = f.read(512)
        if koly[:4] != b"koly":
            raise SystemExit("not a compressed dmg")
        xml_offset, xml_len = struct.unpack(">QQ", koly[216:232])
        f.seek(xml_offset)
        tables = plistlib.loads(f.read(xml_len))["resource-fork"]["blkx"]
        with open(dst, "wb") as out:
            for table in tables:
                data = table["Data"]
                sig, version, sector, sectors, data_offset, buffers, runs = struct.unpack(
                    ">4sIQQQII", data[:40]
                )
                out.seek(sector * 512)
                pos = HEADER_SIZE
                while pos + RUN_SIZE <= len(data):
                    entry_type, comment, run_sector, run_sectors, comp_offset, comp_len = struct.unpack(
                        ">IIQQQQ", data[pos:pos + RUN_SIZE]
                    )
                    pos += RUN_SIZE
                    size = run_sectors * 512
                    if size == 0:
                        continue
                    if entry_type in ZERO_TYPES:
                        out.seek(size, 1)
                    elif entry_type == 1:
                        f.seek(comp_offset)
                        out.write(f.read(size))
                    elif entry_type == 0x80000005:
                        f.seek(comp_offset)
                        out.write(zlib.decompress(f.read(comp_len)))
                    elif entry_type == 0x80000006:
                        f.seek(comp_offset)
                        out.write(bz2.decompress(f.read(comp_len)))
                    else:
                        raise SystemExit("unsupported dmg block type 0x%x" % entry_type)
            out.truncate()


convert(sys.argv[1], sys.argv[2])
PY
}

if [ ! -f BaseSystem.img ]; then
    if [ ! -f BaseSystem.dmg ]; then
        echo "== query apple recovery"
        info="$(recovery_info)"
        printf '%s\n' "$info" | sed -n 's/^\(AP\|AH\|CH\): /\1: /p'
        image_url="$(printf '%s\n' "$info" | awk '/^AU: /{print $2}')"
        image_token="$(printf '%s\n' "$info" | awk '/^AT: /{sub(/^AT: /,""); print}')"
        [ -n "$image_url" ] && [ -n "$image_token" ] || { echo "recovery image not offered" >&2; exit 1; }
        echo "== download BaseSystem.dmg"
        fetch_token_asset "$image_url" "$image_token" BaseSystem.dmg
    fi
    echo "== convert BaseSystem.dmg -> BaseSystem.img"
    dmg_to_raw BaseSystem.dmg BaseSystem.img
fi

if [ ! -f OpenCore.qcow2 ]; then
    echo "== download OpenCore.qcow2"
    fetch_data "$OSXKVM_RAW/OpenCore/OpenCore.qcow2" OpenCore.qcow2
fi

if [ ! -f OVMF_CODE_4M.fd ]; then
    echo "== download OVMF_CODE_4M.fd"
    fetch_data "$OSXKVM_RAW/OVMF_CODE_4M.fd" OVMF_CODE_4M.fd
fi

if [ ! -f OVMF_VARS-1920x1080.fd ]; then
    echo "== download OVMF_VARS-1920x1080.fd"
    fetch_data "$OSXKVM_RAW/OVMF_VARS-1920x1080.fd" OVMF_VARS-1920x1080.fd
fi

[ -f OVMF_VARS.fd ] || cp OVMF_VARS-1920x1080.fd OVMF_VARS.fd

if [ ! -f macOS.qcow2 ]; then
    echo "== create macOS.qcow2 ($DISK_SIZE)"
    qemu-img create -f qcow2 macOS.qcow2 "$DISK_SIZE" >/dev/null
fi

recovery_version=""
if command -v 7z >/dev/null; then
    sysver_plist="macOS Base System/System/Library/CoreServices/SystemVersion.plist"
    7z e -so BaseSystem.img "$sysver_plist" >/dev/null 2>&1 || sysver_plist="System/Library/CoreServices/SystemVersion.plist"
    recovery_version="$(7z e -so BaseSystem.img "$sysver_plist" 2>/dev/null \
        | awk -F'[<>]' '/ProductUserVisibleVersion/{getline; print $3}' || true)"
fi

echo
echo "vm dir   : $VM_DIR"
echo "recovery : ${recovery_version:-unknown}"
ls -la "$VM_DIR"
echo
echo "next: $SCRIPT_DIR/start.sh"
