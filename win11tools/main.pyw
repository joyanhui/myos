# -*- coding: utf-8 -*-
"""win11tools main window: 常用软件安装, 功能区, dotfile 双向同步."""

from __future__ import annotations

import json
import os
import queue
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from dataclasses import dataclass

import tkinter as tk
from tkinter import filedialog, messagebox, ttk

APP_TITLE = "win11tools"
DEFAULT_GHPROXY = "https://gh-proxy.net/"
ALTSNAP_TITLE = "AltSnap"
ALTSNAP_TASK = "AltSnap_AutoStart"
MIHOMO_SVC = "mihomo"
MIHOMO_WINGET_ID = "MetaCubeX.Mihomo"
MIHOMO_CORE_VER = "1.19.33"
MIHOMO_UI_VER = "1.273.0"
APP_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(APP_DIR)
SUPPLY_DIR = os.path.join(APP_DIR, "subtools")
LOCAL_DOTFILES_DIR = os.path.join(APP_DIR, "win11.dotfiles")
STATE_PATH = os.path.join(APP_DIR, "win11tools.json")

FONT_UI = ("Microsoft YaHei UI", 10)
FONT_UI_BOLD = ("Microsoft YaHei UI", 10, "bold")
FONT_TITLE = ("Microsoft YaHei UI", 11, "bold")
FONT_MONO = ("Consolas", 10)

CREATE_NO_WINDOW = 0x08000000
CREATE_NEW_CONSOLE = 0x00000010


def decode_bytes(data: bytes) -> str:
    for enc in ("utf-8", "gbk"):
        try:
            return data.decode(enc)
        except UnicodeDecodeError:
            continue
    return data.decode("utf-8", "replace")


def run_capture(args, timeout=120):
    try:
        proc = subprocess.run(args, capture_output=True, timeout=timeout, creationflags=CREATE_NO_WINDOW)
    except Exception as exc:
        return -1, str(exc)
    return proc.returncode, decode_bytes(proc.stdout + proc.stderr)


def run_ps_command(command: str):
    exe = find_powershell()
    subprocess.Popen([exe, "-NoProfile", "-NoExit", "-Command", command], creationflags=CREATE_NEW_CONSOLE)


def find_powershell() -> str:
    pwsh = shutil.which("pwsh")
    if pwsh:
        return pwsh
    return shutil.which("powershell.exe") or "powershell.exe"


def open_path(path: str):
    if os.path.exists(path):
        os.startfile(path)
        return True
    return False


def open_containing(path: str):
    folder = path if os.path.isdir(path) else os.path.dirname(path)
    if os.path.isdir(folder):
        os.startfile(folder)
        return True
    return False


def find_pythonw() -> str:
    if sys.executable.lower().endswith("pythonw.exe"):
        return sys.executable
    if sys.executable:
        cand = os.path.join(os.path.dirname(sys.executable), "pythonw.exe")
        if os.path.isfile(cand):
            return cand
    return "pythonw.exe"


def default_scoop_dir() -> str:
    env = os.environ.get("SCOOP")
    if env:
        return env
    return os.path.join(os.path.expanduser("~"), "scoop")


def load_state() -> dict:
    try:
        with open(STATE_PATH, "r", encoding="utf-8") as fh:
            data = json.load(fh)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def save_state(data: dict):
    with open(STATE_PATH, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2, ensure_ascii=False)
        fh.write("\n")


@dataclass(frozen=True)
class Package:
    title: str
    desc: str
    backend: str
    names: tuple[str, ...]
    extra_bucket: str = ""
    special: str = ""
    scoop_alias: str = ""


@dataclass(frozen=True)
class DotFile:
    title: str
    target: str
    repo: str

    def target_path(self) -> str:
        return os.path.expandvars(self.target)

    def repo_path(self) -> str:
        return os.path.normpath(os.path.join(APP_DIR, self.repo))

    def repo_display(self) -> str:
        return os.path.relpath(self.repo_path(), REPO_DIR)


PACKAGE_GROUPS = (
    (
        "winget 系统工具",
        (
            Package("PowerShell 7", "Microsoft.PowerShell", "winget", ("Microsoft.PowerShell",)),
            Package("Coreutils", "Microsoft.Coreutils", "winget", ("Microsoft.Coreutils",)),
            Package("Seelen UI", "Seelen.SeelenUI", "winget", ("Seelen.SeelenUI",)),
            Package("DISM++", "ChuyuTeam.DISM++", "winget", ("ChuyuTeam.DISM++",), scoop_alias="dismplusplus"),
            Package("Nushell", "Nushell.Nushell", "winget", ("Nushell.Nushell",)),
            Package("Helix", "Helix.Helix", "winget", ("Helix.Helix",)),
            Package("noctty", "AmanThanvi.noctty", "winget", ("AmanThanvi.noctty",)),
            Package("lazygit", "JesseDuffield.lazygit", "winget", ("JesseDuffield.lazygit",)),
            Package("AltSnap", "AltSnap.AltSnap", "winget", ("AltSnap.AltSnap",)),
        ),
    ),
    (
        "scoop 自身",
        (
            Package("scoop", "安装到上面填写的 scoop 目录", "scoop", ("scoop",), special="scoop_self"),
        ),
    ),
    (
        "scoop 开发环境",
        (
            Package("nodejs-lts + pnpm", "Node.js LTS 与 pnpm", "scoop", ("nodejs-lts", "pnpm")),
            Package("bun", "bun 运行时与包管理器", "scoop", ("bun",)),
            Package("rustup", "Rust 工具链", "scoop", ("rustup",)),
            Package("golang", "Go 工具链", "scoop", ("go",)),
            Package("flutter", "Flutter SDK，需要 extras bucket", "scoop", ("flutter",), extra_bucket="extras"),
            Package("zig", "Zig 工具链", "scoop", ("zig",)),
        ),
    ),
    (
        "scoop 常用软件",
        (
            Package("Chrome", "googlechrome", "scoop", ("googlechrome",)),
            Package("Obsidian", "obsidian", "scoop", ("obsidian",)),
            Package("QQ NT", "qq-nt", "scoop", ("qq-nt",)),
            Package("Telegram", "telegram", "scoop", ("telegram",)),
        ),
    ),
)

DOTFILES = (
    DotFile("noctty config.ghostty", r"%LOCALAPPDATA%\noctty\config.ghostty",
            r"win11.dotfiles\noctty_config.ghostty"),
    DotFile("nvim init.lua", r"%LOCALAPPDATA%\nvim\init.lua",
            r"win11.dotfiles\nvim_win_init.lua"),
    DotFile("helix config.toml", r"%APPDATA%\helix\config.toml",
            r"..\dotfiles\helix_config.toml"),
    DotFile("helix languages.toml", r"%APPDATA%\helix\languages.toml",
            r"..\dotfiles\helix_languages.toml"),
    DotFile("pi settings.json", r"%USERPROFILE%\.pi\agent\settings.json",
            r"..\dotfiles\pi_settings.json"),
    DotFile("pi models.json", r"%USERPROFILE%\.pi\agent\models.json",
            r"..\dotfiles\pi_models.json"),
    DotFile("pi goal.json", r"%USERPROFILE%\.pi\agent\pi-goal.json",
            r"..\dotfiles\pi_goal.json"),
    DotFile("zed settings.json", r"%APPDATA%\Zed\settings.json",
            r"win11.dotfiles\zed_config.json"),
    DotFile("seelen-ui settings.json", r"%APPDATA%\com.seelen.seelen-ui\settings.json",
            r"win11.dotfiles\seelen-ui_setting.json"),
)

FEATURE_ROWS = (
    (
        "onekey_startup.ahk",
        ("启动", "feature_start_onekey"),
        ("自动启动", "feature_toggle_startup"),
        ("编辑", "feature_edit_onekey"),
    ),
)


def scoop_apps_dir(scoop_dir: str) -> str:
    return os.path.join(scoop_dir, "apps")


def scoop_shims_dir(scoop_dir: str) -> str:
    return os.path.join(scoop_dir, "shims")


def scoop_installed(scoop_dir: str) -> bool:
    return (
        os.path.isfile(os.path.join(scoop_shims_dir(scoop_dir), "scoop.cmd"))
        or os.path.isdir(os.path.join(scoop_apps_dir(scoop_dir), "scoop"))
    )


def scoop_prefix(scoop_dir: str, body: str) -> str:
    shims = scoop_shims_dir(scoop_dir)
    path_lower = os.environ.get("PATH", "").lower()
    if shims.lower() in path_lower:
        return body
    return '$env:Path = "{0};" + $env:Path; {1}'.format(shims, body)


def build_install_cmd(pkg: Package, scoop_dir: str) -> str:
    if pkg.backend == "winget":
        return (
            "winget install --id {0} -e --source winget "
            "--accept-package-agreements --accept-source-agreements"
        ).format(pkg.names[0])
    if pkg.special == "scoop_self":
        return (
            "Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force; "
            '$env:SCOOP = "{0}"; '
            "Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression"
        ).format(scoop_dir)
    body = "scoop install " + " ".join(pkg.names)
    if pkg.extra_bucket:
        body = "scoop bucket add {0}; {1}".format(pkg.extra_bucket, body)
    return scoop_prefix(scoop_dir, body)


def build_uninstall_cmd(pkg: Package, scoop_dir: str) -> str:
    if pkg.backend == "winget":
        return "winget uninstall --id {0} -e".format(pkg.names[0])
    body = "scoop uninstall " + " ".join(pkg.names)
    return scoop_prefix(scoop_dir, body)


def norm_name(name: str) -> str:
    return re.sub(r"[^a-z0-9]", "", name.lower())


def scoop_app_names(scoop_dir: str) -> set:
    apps = scoop_apps_dir(scoop_dir)
    if not os.path.isdir(apps):
        return set()
    return {norm_name(name) for name in os.listdir(apps)}


def pkg_state(pkg: Package, winget_text: str, scoop_dir: str, scoop_apps=None) -> str:
    if scoop_apps is None:
        scoop_apps = scoop_app_names(scoop_dir)
    if pkg.special == "scoop_self":
        return "scoop 已安装" if scoop_installed(scoop_dir) else "未安装"
    if pkg.backend == "winget":
        low = winget_text.lower()
        if all(n.lower() in low for n in pkg.names):
            return "winget 已安装"
        probes = [pkg.scoop_alias] if pkg.scoop_alias else [n.split(".")[-1] for n in pkg.names]
        if any(norm_name(probe) in scoop_apps for probe in probes):
            return "scoop 已安装"
        return "未安装"
    present = [n for n in pkg.names if norm_name(n) in scoop_apps]
    if len(present) == len(pkg.names):
        return "scoop 已安装"
    if present:
        return "scoop 部分安装 {0}/{1}".format(len(present), len(pkg.names))
    return "未安装"


def winget_list_text() -> str:
    rc, out = run_capture(["winget", "list", "--accept-source-agreements"], timeout=180)
    if rc != 0 and not out.strip():
        return ""
    return out


def find_altsnap_exe(scoop_dir: str) -> str:
    cands = []
    apps = os.path.join(scoop_apps_dir(scoop_dir), "altsnap")
    cands.append(os.path.join(apps, "current", "AltSnap.exe"))
    if os.path.isdir(apps):
        for name in sorted(os.listdir(apps), reverse=True):
            cands.append(os.path.join(apps, name, "AltSnap.exe"))
    for var in ("APPDATA", "LOCALAPPDATA", "ProgramFiles", "ProgramFiles(x86)"):
        base = os.environ.get(var)
        if not base:
            continue
        cands.append(os.path.join(base, "AltSnap", "AltSnap.exe"))
        cands.append(os.path.join(base, "Programs", "AltSnap", "AltSnap.exe"))
    task_command = scheduled_task_command(ALTSNAP_TASK)
    if task_command:
        cands.append(task_command)
    for cand in cands:
        if os.path.isfile(cand):
            return cand
    found = shutil.which("AltSnap.exe") or shutil.which("altsnap.exe")
    return found or ""


def scheduled_task_command(name: str) -> str:
    rc, out = run_capture(["schtasks", "/Query", "/TN", name, "/XML"])
    if rc != 0:
        return ""
    match = re.search(r"<Command>(.*?)</Command>", out, re.S)
    return match.group(1).strip() if match else ""


def task_exists(name: str) -> bool:
    rc, _out = run_capture(["schtasks", "/Query", "/TN", name])
    return rc == 0


def altsnap_startup_script(exe: str) -> str:
    lines = [
        "$ErrorActionPreference = 'Stop'",
        "$exe = '{0}'".format(ps_quote(exe)),
        '$user = "$env:USERDOMAIN\\$env:USERNAME"',
        "$action = New-ScheduledTaskAction -Execute $exe -WorkingDirectory (Split-Path $exe)",
        "$trigger = New-ScheduledTaskTrigger -AtLogOn -User $user",
        "$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest",
        "$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries "
        "-DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero)",
        "Register-ScheduledTask -TaskName '{0}' -Action $action -Trigger $trigger "
        "-Principal $principal -Settings $settings -Force | Out-Null".format(ALTSNAP_TASK),
    ]
    return "\r\n".join(lines) + "\r\n"


def altsnap_delete_script() -> str:
    lines = [
        "$ErrorActionPreference = 'Stop'",
        "schtasks /Delete /TN '{0}' /F | Out-Null".format(ALTSNAP_TASK),
    ]
    return "\r\n".join(lines) + "\r\n"


def run_elevated_script(script_text: str):
    path = os.path.join(tempfile.gettempdir(), "win11tools_elevated.ps1")
    with open(path, "w", encoding="utf-8-sig", newline="") as fh:
        fh.write(script_text)
    launcher = (
        "$p = Start-Process -FilePath '{exe}' "
        "-ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File','{script}') "
        "-Verb RunAs -PassThru -Wait; exit $p.ExitCode"
    ).format(exe=ps_quote(find_powershell()), script=ps_quote(path))
    rc, out = run_capture([find_powershell(), "-NoProfile", "-Command", launcher], timeout=180)
    try:
        os.remove(path)
    except OSError:
        pass
    return rc, out


def startup_folder() -> str:
    return os.path.join(os.environ.get("APPDATA", ""), r"Microsoft\Windows\Start Menu\Programs\Startup")


def startup_shortcut() -> str:
    return os.path.join(startup_folder(), "onekey_startup.lnk")


def find_ahk_exe(scoop_dir: str = "") -> str:
    cands = []
    roots = []
    if scoop_dir:
        roots.append(scoop_dir)
    if os.environ.get("SCOOP"):
        roots.append(os.environ["SCOOP"])
    roots.append(default_scoop_dir())
    for root in roots:
        ahk_root = os.path.join(root, "apps", "autohotkey")
        cands.append(os.path.join(ahk_root, "current", "v2", "AutoHotkey64.exe"))
        if os.path.isdir(ahk_root):
            for name in sorted(os.listdir(ahk_root), reverse=True):
                cands.append(os.path.join(ahk_root, name, "v2", "AutoHotkey64.exe"))
    for var in ("ProgramFiles", "ProgramFiles(x86)", "LOCALAPPDATA"):
        base = os.environ.get(var)
        if base:
            cands.append(os.path.join(base, "AutoHotkey", "v2", "AutoHotkey64.exe"))
            cands.append(os.path.join(base, "Programs", "AutoHotkey", "v2", "AutoHotkey64.exe"))
    for cand in cands:
        if os.path.isfile(cand):
            return cand
    return ""


def onekey_script() -> str:
    return os.path.join(SUPPLY_DIR, "onekey_startup.ahk")


def copy_file(src: str, dst: str):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)


def mihomo_home() -> str:
    base = os.environ.get("LOCALAPPDATA") or os.path.expanduser("~")
    return os.path.join(base, "mihomo")


def mihomo_data_home() -> str:
    base = os.path.join(os.environ.get("USERPROFILE") or os.path.expanduser("~"), ".config", "mihomo")
    if os.path.isdir(base):
        return base
    xdg = os.environ.get("XDG_CONFIG_HOME", "").strip()
    return os.path.join(xdg, "mihomo") if xdg else base


def mihomo_cfg_path() -> str:
    return os.path.join(mihomo_data_home(), "config.yaml")


def find_mihomo_exe() -> str:
    cands = [os.path.join(mihomo_home(), "mihomo.exe")]
    local = os.environ.get("LOCALAPPDATA", "")
    if local:
        cands.append(os.path.join(local, "Microsoft", "WinGet", "Links", "mihomo.exe"))
        packages = os.path.join(local, "Microsoft", "WinGet", "Packages")
        if os.path.isdir(packages):
            for name in sorted(os.listdir(packages), reverse=True):
                if not name.lower().startswith("metacubex.mihomo"):
                    continue
                folder = os.path.join(packages, name)
                cands.append(os.path.join(folder, "mihomo.exe"))
                for root, _dirs, files in os.walk(folder):
                    if "mihomo.exe" in [f.lower() for f in files]:
                        cands.append(os.path.join(root, "mihomo.exe"))
                        break
    for cand in cands:
        if os.path.isfile(cand):
            return cand
    return shutil.which("mihomo.exe") or shutil.which("mihomo") or ""


def gh_url(proxy: str, path: str) -> str:
    if not re.match(r"^https?://", path):
        path = "https://github.com/" + path
    proxy = (proxy or "").strip()
    return proxy.rstrip("/") + "/" + path if proxy else path


def svc_state(name: str) -> str:
    rc, out = run_capture(["sc.exe", "query", name])
    if rc != 0:
        return ""
    return "RUNNING" if "RUNNING" in out.upper() else "STOPPED"


def mihomo_core_version() -> str:
    exe = find_mihomo_exe()
    if not exe:
        return ""
    _rc, out = run_capture([exe, "-v"], timeout=10)
    for line in out.splitlines():
        line = line.strip()
        if line:
            return line
    return ""


def mihomo_panel_ver() -> str:
    data = mihomo_data_home()
    if not os.path.isdir(os.path.join(data, "ui")):
        return "未安装"
    try:
        with open(os.path.join(data, ".win11tools_ui_ver"), encoding="utf-8") as fh:
            return "v" + fh.read().strip()
    except OSError:
        return "已安装"


def mihomo_template_path() -> str:
    path = os.path.join(REPO_DIR, "security", "placeholder_files", "mihomo.yaml")
    return path if os.path.isfile(path) else ""


def ensure_mihomo_cfg() -> str:
    path = mihomo_cfg_path()
    if os.path.isfile(path):
        return path
    src = mihomo_template_path()
    if not src:
        return ""
    folder = os.path.dirname(path)
    if folder:
        os.makedirs(folder, exist_ok=True)
    shutil.copy2(src, path)
    return path


def find_nssm(scoop_dir: str) -> str:
    cands = [os.path.join(mihomo_home(), "nssm.exe"),
             os.path.join(scoop_apps_dir(scoop_dir), "nssm", "current", "win64", "nssm.exe")]
    apps = os.path.join(scoop_apps_dir(scoop_dir), "nssm")
    if os.path.isdir(apps):
        for name in sorted(os.listdir(apps), reverse=True):
            cands.append(os.path.join(apps, name, "win64", "nssm.exe"))
    for cand in cands:
        if os.path.isfile(cand):
            return cand
    return ""


def http_download(url: str, dest: str, progress=None):
    import urllib.request

    req = urllib.request.Request(url, headers={"User-Agent": "win11tools"})
    total = 0
    done = 0
    with urllib.request.urlopen(req, timeout=90) as resp:
        total = int(resp.headers.get("Content-Length") or 0)
        with open(dest, "wb") as fh:
            while True:
                chunk = resp.read(65536)
                if not chunk:
                    break
                fh.write(chunk)
                done += len(chunk)
                if progress and total:
                    progress(min(99, int(done * 100 / total)))
    if not done:
        raise RuntimeError("下载内容为空: " + url)
    return dest


def download_zip_member(url: str, member: str, extract_to: str, progress=None) -> str:
    import zipfile

    zip_path = extract_to.rstrip("\\/") + ".zip"
    http_download(url, zip_path, progress)
    shutil.rmtree(extract_to, ignore_errors=True)
    try:
        with zipfile.ZipFile(zip_path) as zf:
            zf.extractall(extract_to)
    except zipfile.BadZipFile:
        try:
            os.remove(zip_path)
        except OSError:
            pass
        raise RuntimeError("下载到的不是 zip（代理可能返回了网页）: " + url)
    finally:
        try:
            os.remove(zip_path)
        except OSError:
            pass
    hits = []
    for root, _dirs, files in os.walk(extract_to):
        for name in files:
            if name.lower() == member.lower():
                hits.append(os.path.join(root, name))
    if not hits:
        raise RuntimeError("压缩包内未找到 {0}".format(member))
    hits.sort(key=lambda p: 0 if "win64" in p.lower() else 1)
    return hits[0]


def github_urls(proxy: str, path: str):
    urls = [gh_url(proxy, path)]
    direct = gh_url("", path)
    if direct not in urls:
        urls.append(direct)
    return urls


def download_github_zip(proxy: str, path: str, member: str, extract_to: str, progress=None, log=None):
    problems = []
    urls = github_urls(proxy, path)
    for idx, url in enumerate(urls):
        try:
            return download_zip_member(url, member, extract_to, progress)
        except Exception as exc:
            problems.append("{0} -> {1}".format(url, exc))
            if log and idx + 1 < len(urls):
                log("warn", "下载失败（{0}），改用直连 GitHub 重试".format(exc))
    raise RuntimeError("下载失败: " + "；".join(problems))


def get_github_json(proxy: str, path: str, log=None):
    import json as json_mod
    import urllib.request

    problems = []
    urls = github_urls(proxy, path)
    for idx, url in enumerate(urls):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "win11tools"})
            with urllib.request.urlopen(req, timeout=60) as resp:
                return json_mod.loads(resp.read().decode("utf-8"))
        except Exception as exc:
            problems.append("{0} -> {1}".format(url, exc))
            if log and idx + 1 < len(urls):
                log("warn", "查询失败（{0}），改用直连 GitHub 重试".format(exc))
    raise RuntimeError("查询失败: " + "；".join(problems))


def run_elevated_lines(lines):
    script = "\r\n".join(["$ErrorActionPreference = 'Stop'"] + [str(x) for x in lines]) + "\r\n"
    return run_elevated_script(script)


OPENWRT_TPL = r"""#!/bin/sh
# mihomo 一键安装到 OpenWrt（自启 = procd 标准服务）
# 用法：整段粘贴到路由器终端（root）执行；自动识别架构下载核心
set -e
VER=@@VER@@
GH_BASE='@@GH_BASE@@'
PROG=/usr/bin/mihomo
RUN_DIR=/etc/mihomo
CONFIG=/etc/mihomo/config.yaml

#1) 架构 -> 发布物
ARCH=$(uname -m)
case "$ARCH" in
x86_64) SUB=amd64 ;;
aarch64) SUB=arm64 ;;
armv7*) SUB=armv7 ;;
armv6*) SUB=armv6 ;;
armv5*) SUB=armv5 ;;
mips64el) SUB=mips64le ;;
mips64) SUB=mips64 ;;
mipsel) SUB=mipsle-softfloat ;;
mips) SUB=mips-softfloat ;;
riscv64) SUB=riscv64 ;;
*) echo "不支持的架构: $ARCH"; exit 1 ;;
esac
mkdir -p "$RUN_DIR"

fetch() {
    if command -v curl >/dev/null 2>&1; then curl -fsSL -o "$1" "$2"
    else wget -q -O "$1" "$2"; fi
}

#2) 下载 mihomo 核心（amd64 在老 CPU 上跑不起来时自动换 compatible 版）
URL="$GH_BASE/MetaCubeX/mihomo/releases/download/v$VER/mihomo-linux-$SUB-v$VER.gz"
echo "下载 $URL"
fetch /tmp/mihomo.gz "$URL"
[ -s /tmp/mihomo.gz ] || { echo "ERROR: 下载失败: $URL"; exit 1; }
gzip -dc /tmp/mihomo.gz > "$PROG"
chmod +x "$PROG"
rm -f /tmp/mihomo.gz
if ! "$PROG" -v >/dev/null 2>&1; then
    if [ "$SUB" = amd64 ]; then
        echo "amd64 版跑不起来（老 CPU），改下 compatible 版"
        URL="$GH_BASE/MetaCubeX/mihomo/releases/download/v$VER/mihomo-linux-amd64-compatible-v$VER.gz"
        fetch /tmp/mihomo.gz "$URL"
        [ -s /tmp/mihomo.gz ] || { echo "ERROR: 下载失败: $URL"; exit 1; }
        gzip -dc /tmp/mihomo.gz > "$PROG"
        chmod +x "$PROG"
        rm -f /tmp/mihomo.gz
    else
        echo "ERROR: mihomo 执行失败"
        exit 1
    fi
fi

#3) 配置（没有才写占位配置；覆盖成完整配置后 /etc/init.d/mihomo reload）
if [ ! -f "$CONFIG" ]; then
    cat > "$CONFIG" <<'YAML'
mixed-port: 7890
allow-lan: true
mode: rule
log-level: info
ipv6: false
external-controller: 0.0.0.0:9090
dns:
  enable: true
  listen: 0.0.0.0:1053
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver:
    - 223.5.5.5
    - 8.8.8.8
proxies: []
proxy-groups: []
rules: []
YAML
    echo "已写占位配置 $CONFIG（把完整配置覆盖进来后执行 /etc/init.d/mihomo reload）"
fi

#4) 清掉旧的自启方式（rc.local 裸跑 / 旧 init 脚本），换 procd 标准服务
p=$(pidof mihomo 2>/dev/null || true)
[ -n "$p" ] && kill $p 2>/dev/null || true
[ -f /etc/rc.local ] && sed -i '/mihomo/d' /etc/rc.local 2>/dev/null || true
cat > /etc/init.d/mihomo <<'EOF'
#!/bin/sh /etc/rc.common
START=95
STOP=05
USE_PROCD=1
PROG=/usr/bin/mihomo
RUN_DIR=/etc/mihomo
CONFIG=/etc/mihomo/config.yaml
start_service() {
    procd_open_instance
    procd_set_param command "$PROG" -d "$RUN_DIR" -f "$CONFIG"
    procd_set_param respawn
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param file "$CONFIG"
    procd_set_param reload_signal HUP
    procd_set_param limits core="unlimited"
    procd_close_instance
}
reload_service() {
    procd_send_signal mihomo HUP
}
service_triggers() {
    procd_add_reload_trigger "mihomo"
}
EOF
chmod +x /etc/init.d/mihomo
/etc/init.d/mihomo enable

#5) 先校验配置再启动
if ! "$PROG" -t -d "$RUN_DIR" -f "$CONFIG" >/dev/null 2>&1; then
    echo "WARN: 配置校验不过（$CONFIG），服务可能起不来"
fi
/etc/init.d/mihomo start || /etc/init.d/mihomo restart
sleep 1
if [ -n "$(pidof mihomo)" ]; then
    echo "OK: mihomo 已运行（procd 托管，开机自启）"
else
    echo "WARN: mihomo 没起来，看日志: logread -e mihomo"
fi
echo "常用命令: /etc/init.d/mihomo {start|stop|restart|reload|enable|disable}"
echo "改配置 $CONFIG 后: /etc/init.d/mihomo reload"
"""


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(APP_TITLE)
        self.geometry("1680x1050")
        self.minsize(960, 600)
        self.state_data = load_state()
        self.scoop_dir = self.state_data.get("scoop_dir") or default_scoop_dir()
        self.ghproxy = self.state_data.get("ghproxy") or DEFAULT_GHPROXY
        self.winget_text = ""
        self.current_pkg = None
        self.pkg_states = {}
        self.dot_rows = {}
        self.pkg_queue = queue.Queue()
        self.pkg_gen = 0
        self.setup_style()
        self.build_ui()
        self.refresh_packages()
        self.refresh_dotfiles()
        self.refresh_feature_status()
        self.refresh_mihomo()
        self.set_status("就绪")

    def setup_style(self):
        style = ttk.Style(self)
        try:
            style.theme_use("vista")
        except tk.TclError:
            pass
        style.configure(".", font=FONT_UI)
        style.configure("Treeview", font=FONT_UI, rowheight=24)
        style.configure("Treeview.Heading", font=FONT_UI_BOLD)
        style.configure("Title.TLabel", font=FONT_TITLE)
        style.configure("Desc.TLabel", foreground="#555555")

    def build_ui(self):
        status_bar = ttk.Frame(self, padding=(10, 4))
        status_bar.pack(side="bottom", fill="x")
        self.status_var = tk.StringVar(value="就绪")
        ttk.Label(status_bar, textvariable=self.status_var, anchor="w").pack(side="left", fill="x", expand=True)
        self.scoop_state_var = tk.StringVar(value="")
        ttk.Label(status_bar, textvariable=self.scoop_state_var, anchor="e").pack(side="right")

        self.build_packages_block(self)
        self.build_features_block(self)
        self.build_mihomo_block(self)
        self.build_dotfiles_block(self)

    def set_status(self, msg: str):
        self.status_var.set(msg)

    def build_packages_block(self, parent):
        frame = ttk.LabelFrame(parent, text="常用软件", padding=10)
        frame.pack(fill="both", expand=True, padx=10, pady=(10, 0))

        top = ttk.Frame(frame)
        top.pack(fill="x")
        self.scoop_label_var = tk.StringVar()
        ttk.Label(top, textvariable=self.scoop_label_var).pack(side="left")
        ttk.Button(top, text="刷新检测", command=self.refresh_packages).pack(side="right")
        ttk.Button(top, text="首选项", command=self.open_preferences).pack(side="right", padx=6)
        self.update_scoop_label()

        body = ttk.Panedwindow(frame, orient="horizontal")
        body.pack(fill="both", expand=True, pady=(10, 0))

        left = ttk.Frame(body, padding=(0, 0, 8, 0))
        body.add(left, weight=1)
        ttk.Label(left, text="分区", style="Title.TLabel").pack(anchor="w", pady=(0, 6))
        self.group_list = tk.Listbox(left, exportselection=False, font=FONT_UI, activestyle="none")
        self.group_list.pack(fill="both", expand=True)
        for title, _ in PACKAGE_GROUPS:
            self.group_list.insert("end", title)
        self.group_list.bind("<<ListboxSelect>>", lambda _e: self.show_group())

        right = ttk.Frame(body)
        body.add(right, weight=3)
        ttk.Label(right, text="软件列表（双击可选行生成安装命令）", style="Title.TLabel").pack(anchor="w", pady=(0, 6))
        tree_wrap = ttk.Frame(right)
        tree_wrap.pack(fill="both", expand=True)
        self.pkg_tree = ttk.Treeview(tree_wrap, columns=("state", "desc"), show="tree headings", selectmode="browse")
        self.pkg_tree.heading("#0", text="名称")
        self.pkg_tree.column("#0", width=220, anchor="w")
        self.pkg_tree.heading("state", text="状态")
        self.pkg_tree.column("state", width=120, anchor="w")
        self.pkg_tree.heading("desc", text="说明")
        self.pkg_tree.column("desc", width=420, anchor="w")
        scroll = ttk.Scrollbar(tree_wrap, orient="vertical", command=self.pkg_tree.yview)
        self.pkg_tree.configure(yscrollcommand=scroll.set)
        self.pkg_tree.pack(side="left", fill="both", expand=True)
        scroll.pack(side="right", fill="y")
        self.pkg_tree.bind("<<TreeviewSelect>>", lambda _e: self.on_pkg_select())
        self.pkg_tree.bind("<Double-1>", lambda _e: self.fill_cmd("install"))
        self.pkg_tree.tag_configure("installed", foreground="#1a7f37")
        self.pkg_tree.tag_configure("missing", foreground="#a8071a")

        cmd_box = ttk.LabelFrame(frame, text="命令（可编辑后复制或运行）", padding=8)
        cmd_box.pack(fill="x", pady=(10, 0))
        self.cmd_var = tk.StringVar()
        ttk.Entry(cmd_box, textvariable=self.cmd_var, font=FONT_MONO).pack(fill="x")
        row = ttk.Frame(cmd_box)
        row.pack(fill="x", pady=(8, 0))
        ttk.Button(row, text="生成安装命令", command=lambda: self.fill_cmd("install")).pack(side="left")
        ttk.Button(row, text="生成卸载命令", command=lambda: self.fill_cmd("uninstall")).pack(side="left", padx=6)
        ttk.Button(row, text="复制", command=self.copy_cmd).pack(side="left")
        ttk.Button(row, text="运行 (PowerShell)", command=self.run_cmd).pack(side="left", padx=6)
        self.altsnap_startup_btn = ttk.Button(row, text="配置管理员开机启动",
                                              command=self.toggle_altsnap_startup)
        ttk.Label(row, text="提示：安装/卸载完成后点“刷新检测”更新状态", style="Desc.TLabel").pack(side="right")

        self.group_list.selection_set(0)
        self.show_group()

    def build_features_block(self, parent):
        frame = ttk.LabelFrame(parent, text="功能区", padding=10)
        frame.pack(fill="x", padx=10, pady=(10, 0))

        grid = ttk.Frame(frame)
        grid.pack(fill="x", anchor="nw")
        for row, item in enumerate(FEATURE_ROWS):
            ttk.Label(grid, text=item[0], style="Title.TLabel").grid(
                row=row, column=0, sticky="w", padx=(0, 20), pady=6)
            for col, (label, method) in enumerate(item[1:], start=1):
                btn = ttk.Button(grid, text=label, width=16, command=getattr(self, method))
                btn.grid(row=row, column=col, sticky="w", padx=(0, 8), pady=6)
                if method == "feature_toggle_startup":
                    self.startup_toggle_btn = btn
        ttk.Label(frame, text="自动启动写入当前用户启动文件夹的 onekey_startup.lnk", style="Desc.TLabel").pack(
            anchor="w", pady=(12, 0))

    def build_mihomo_block(self, parent):
        frame = ttk.LabelFrame(parent, text="mihomo 管理", padding=10)
        frame.pack(fill="x", padx=10, pady=(10, 0))

        self.mihomo_state_var = tk.StringVar(value="检测中 ...")
        ttk.Label(frame, textvariable=self.mihomo_state_var, style="Desc.TLabel").pack(anchor="w")

        buttons = ttk.Frame(frame)
        buttons.pack(fill="x", pady=(8, 0))
        specs = (
            ("安装 / 更新（winget）", self.on_mihomo_install),
            ("启动服务", lambda: self.on_mihomo_svc("start")),
            ("停止服务", lambda: self.on_mihomo_svc("stop")),
            ("卸载（服务 + 文件）", self.on_mihomo_uninstall),
            ("查最新版", self.on_mihomo_latest),
            ("打开配置", self.on_mihomo_open_cfg),
            ("打开数据目录", lambda: self.on_mihomo_open(mihomo_data_home())),
            ("打开安装目录", lambda: self.on_mihomo_open(mihomo_home())),
            ("OpenWrt 命令", self.on_mihomo_openwrt),
        )
        self.mihomo_buttons = []
        for idx, (text, command) in enumerate(specs):
            btn = ttk.Button(buttons, text=text, command=command)
            btn.grid(row=idx // 5, column=idx % 5, sticky="we", padx=3, pady=2)
            self.mihomo_buttons.append(btn)
        for col in range(5):
            buttons.columnconfigure(col, weight=1)

        self.mihomo_progress_bar = ttk.Progressbar(frame, maximum=100)
        self.mihomo_progress_bar.pack(fill="x", pady=(8, 0))

        log_wrap = ttk.Frame(frame)
        log_wrap.pack(fill="x", pady=(6, 0))
        self.mihomo_log_text = tk.Text(log_wrap, height=6, wrap="none", font=FONT_MONO, state="disabled")
        scroll = ttk.Scrollbar(log_wrap, orient="vertical", command=self.mihomo_log_text.yview)
        self.mihomo_log_text.configure(yscrollcommand=scroll.set)
        self.mihomo_log_text.pack(side="left", fill="both", expand=True)
        scroll.pack(side="right", fill="y")
        for level, color in (("info", "#333333"), ("ok", "#1a7f37"), ("warn", "#b26a00"), ("error", "#a8071a")):
            self.mihomo_log_text.tag_config(level, foreground=color)

        self.mihomo_queue = queue.Queue()
        self.mihomo_busy = False

    def log_mihomo(self, level, text):
        self.mihomo_log_text.configure(state="normal")
        self.mihomo_log_text.insert("end", "[{0}] [{1}] {2}\n".format(time.strftime("%H:%M:%S"), level, text), level)
        self.mihomo_log_text.see("end")
        self.mihomo_log_text.configure(state="disabled")

    def mihomo_log(self, level, text):
        self.mihomo_queue.put(("log", level, text))

    def mihomo_progress(self, value):
        self.mihomo_queue.put(("progress", value))

    def refresh_mihomo(self):
        exe = find_mihomo_exe()
        core = "未安装"
        if exe:
            version = mihomo_core_version()
            core = "已安装（{0}）".format(version) if version else "已安装"
        state = svc_state(MIHOMO_SVC)
        service = "运行中" if state == "RUNNING" else ("已停止" if state == "STOPPED" else "未注册")
        cfg = mihomo_cfg_path()
        self.mihomo_state_var.set("核心: {0}    服务: {1}    面板: {2}    配置: {3}（{4}）".format(
            core, service, mihomo_panel_ver(), cfg, "存在" if os.path.isfile(cfg) else "不存在"))

    def set_mihomo_busy(self, busy):
        self.mihomo_busy = busy
        state = ["disabled"] if busy else ["!disabled"]
        for btn in self.mihomo_buttons:
            btn.state(state)
        if not busy:
            self.mihomo_progress_bar["value"] = 0

    def run_mihomo_job(self, label, fn):
        if self.mihomo_busy:
            self.log_mihomo("warn", "已有任务在运行，稍后再试")
            return
        self.set_mihomo_busy(True)
        self.set_status("{0} ...".format(label))

        def work():
            try:
                fn()
                self.mihomo_queue.put(("done", label))
            except Exception as exc:
                self.mihomo_queue.put(("error", label, str(exc)))

        threading.Thread(target=work, daemon=True).start()
        self.after(120, self.poll_mihomo_job)

    def poll_mihomo_job(self):
        finished = False
        try:
            while True:
                msg = self.mihomo_queue.get_nowait()
                kind = msg[0]
                if kind == "progress":
                    self.mihomo_progress_bar["value"] = msg[1]
                elif kind == "log":
                    self.log_mihomo(msg[1], msg[2])
                elif kind == "done":
                    self.log_mihomo("ok", "{0} 完成".format(msg[1]))
                    self.set_status("{0} 完成".format(msg[1]))
                    finished = True
                elif kind == "error":
                    self.log_mihomo("error", "{0} 失败: {1}".format(msg[1], msg[2]))
                    self.set_status("{0} 失败".format(msg[1]))
                    finished = True
        except queue.Empty:
            pass
        if finished:
            self.set_mihomo_busy(False)
            self.refresh_mihomo()
            return
        if self.mihomo_busy:
            self.after(150, self.poll_mihomo_job)

    def on_mihomo_install(self):
        if svc_state(MIHOMO_SVC) and not messagebox.askyesno(
                APP_TITLE, "mihomo 服务已存在，重新安装会用最新核心与面板覆盖？"):
            return
        self.run_mihomo_job("安装 / 更新 mihomo", self.job_mihomo_install)

    def on_mihomo_svc(self, action):
        state = svc_state(MIHOMO_SVC)
        if action == "start" and state == "RUNNING":
            self.log_mihomo("warn", "服务已在运行")
            return
        if action == "stop" and state in ("", "STOPPED"):
            self.log_mihomo("warn", "服务未在运行（{0}）".format("未注册" if not state else "已停止"))
            return
        label = "启动 mihomo 服务" if action == "start" else "停止 mihomo 服务"
        self.run_mihomo_job(label, lambda: self.job_mihomo_svc(action))

    def on_mihomo_uninstall(self):
        if not messagebox.askyesno(
                APP_TITLE,
                "停止并删除 mihomo 服务，删除安装目录 {0}，并卸载 winget 包 {1}？\n"
                "（数据目录 {2} 保留）".format(mihomo_home(), MIHOMO_WINGET_ID, mihomo_data_home())):
            return
        self.run_mihomo_job("卸载 mihomo", self.job_mihomo_uninstall)

    def on_mihomo_latest(self):
        self.run_mihomo_job("查询 mihomo 最新版", self.job_mihomo_latest)

    def on_mihomo_open_cfg(self):
        path = ensure_mihomo_cfg()
        if not path or not os.path.isfile(path):
            self.log_mihomo("warn", "配置文件不存在且没有模板：security/placeholder_files/mihomo.yaml")
            return
        self.on_mihomo_open(path)

    def on_mihomo_open(self, path):
        if os.path.isdir(path):
            os.makedirs(path, exist_ok=True)
        if open_containing(path):
            self.set_status("已打开：{0}".format(path))
        else:
            self.log_mihomo("warn", "路径不存在：{0}".format(path))

    def on_mihomo_openwrt(self):
        base = (self.ghproxy or "").strip().rstrip("/")
        gh_base = "https://github.com" if not base else base + "/https://github.com"
        text = OPENWRT_TPL.replace("@@VER@@", MIHOMO_CORE_VER).replace("@@GH_BASE@@", gh_base)
        self.clipboard_clear()
        self.clipboard_append(text)
        path = os.path.join(tempfile.gettempdir(), "mihomo-openwrt.sh")
        try:
            with open(path, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(text)
        except OSError:
            path = ""
        self.log_mihomo("ok", "OpenWrt 安装命令已复制（核心 v{0}，下载前缀 {1}）".format(MIHOMO_CORE_VER, gh_base))
        if path:
            self.log_mihomo("info", "另存：{0}".format(path))
        self.set_status("OpenWrt 安装命令已复制到剪贴板")

    def job_mihomo_install(self):
        exe = find_mihomo_exe()
        if not exe:
            self.mihomo_log("info", "winget install --id {0} -e".format(MIHOMO_WINGET_ID))
            rc, out = run_elevated_lines([
                "winget install --id {0} -e --source winget "
                "--accept-package-agreements --accept-source-agreements".format(MIHOMO_WINGET_ID),
            ])
            if rc != 0:
                raise RuntimeError("winget 安装失败（rc={0}）: {1}".format(rc, (out or "").strip()[-400:]))
            for _ in range(20):
                exe = find_mihomo_exe()
                if exe:
                    break
                time.sleep(0.5)
            if not exe:
                raise RuntimeError("winget 安装后仍找不到 mihomo.exe")
        self.mihomo_log("ok", "核心：{0}".format(exe))

        data = mihomo_data_home()
        ui_dir = os.path.join(data, "ui")
        staging = os.path.join(tempfile.gettempdir(), "win11tools_mihomo_ui")
        url = gh_url(self.ghproxy, "MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip")
        self.mihomo_log("info", "下载面板：{0}".format(url))
        index_html = download_github_zip(self.ghproxy, "MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip",
                                         "index.html", staging, self.mihomo_progress, self.mihomo_log)
        ui_src = os.path.dirname(index_html)

        cfg = ensure_mihomo_cfg()
        if not cfg:
            raise RuntimeError("配置模板缺失：security/placeholder_files/mihomo.yaml")
        self.mihomo_log("ok", "配置：{0}".format(cfg))

        nssm = find_nssm(self.scoop_dir)
        if not nssm:
            self.mihomo_log("info", "nssm 不在，下载 nssm 2.24")
            member = download_zip_member("https://nssm.cc/release/nssm-2.24.zip", "nssm.exe",
                                         os.path.join(tempfile.gettempdir(), "win11tools_nssm"),
                                         self.mihomo_progress)
            os.makedirs(mihomo_home(), exist_ok=True)
            nssm = os.path.join(mihomo_home(), "nssm.exe")
            shutil.copy2(member, nssm)
        self.mihomo_log("ok", "nssm：{0}".format(nssm))

        existed = bool(svc_state(MIHOMO_SVC))
        backup_ui = os.path.join(tempfile.gettempdir(), "win11tools_mihomo_ui_bak")
        shutil.rmtree(backup_ui, ignore_errors=True)
        moved = False
        try:
            os.makedirs(data, exist_ok=True)
            if os.path.isdir(ui_dir):
                shutil.move(ui_dir, backup_ui)
                moved = True
            shutil.copytree(ui_src, ui_dir)
            with open(os.path.join(data, ".win11tools_ui_ver"), "w", encoding="utf-8") as fh:
                fh.write(MIHOMO_UI_VER)
            params = '-d "{0}" -f "{1}"'.format(data, cfg)
            lines = []
            if existed:
                lines.append('"{0}" stop {1}'.format(nssm, MIHOMO_SVC))
            else:
                lines.append('"{0}" install {1} "{2}"'.format(nssm, MIHOMO_SVC, exe))
            lines += [
                '"{0}" set {1} Application "{2}"'.format(nssm, MIHOMO_SVC, exe),
                '"{0}" set {1} AppDirectory "{2}"'.format(nssm, MIHOMO_SVC, data),
                '"{0}" set {1} AppParameters {2}'.format(nssm, MIHOMO_SVC, params),
                '"{0}" set {1} Start SERVICE_AUTO_START'.format(nssm, MIHOMO_SVC),
                '"{0}" set {1} DisplayName mihomo'.format(nssm, MIHOMO_SVC),
                "sc.exe start {0}".format(MIHOMO_SVC),
            ]
            rc, out = run_elevated_lines(lines)
            if rc != 0:
                raise RuntimeError("服务注册失败（rc={0}）: {1}".format(rc, (out or "").strip()[-400:]))
            state = ""
            for _ in range(20):
                state = svc_state(MIHOMO_SVC)
                if state == "RUNNING":
                    break
                time.sleep(0.5)
            if state != "RUNNING":
                raise RuntimeError("服务没跑起来（{0}）".format(state or "未注册"))
        except Exception:
            shutil.rmtree(ui_dir, ignore_errors=True)
            if moved:
                shutil.move(backup_ui, ui_dir)
            if not existed:
                run_elevated_lines(["sc.exe delete {0}".format(MIHOMO_SVC)])
            raise
        finally:
            shutil.rmtree(backup_ui, ignore_errors=True)
            shutil.rmtree(staging, ignore_errors=True)
        self.mihomo_log("ok", "服务已运行并开机自启（-d {0} -f {1}）".format(data, cfg))

    def job_mihomo_svc(self, action):
        rc, out = run_elevated_lines(["net {0} {1}".format(action, MIHOMO_SVC)])
        time.sleep(1.5)
        state = svc_state(MIHOMO_SVC)
        ok = state == "RUNNING" if action == "start" else state in ("", "STOPPED")
        if not ok:
            raise RuntimeError("{0} 后状态异常：{1}（rc={2} {3}）".format(
                action, state or "未注册", rc, (out or "").strip()[-200:]))
        self.mihomo_log("ok", "服务已{0}".format("启动" if action == "start" else "停止"))

    def job_mihomo_uninstall(self):
        home = mihomo_home()
        rc, out = run_elevated_lines([
            "net stop {0}".format(MIHOMO_SVC),
            "sc.exe delete {0}".format(MIHOMO_SVC),
            'rmdir /s /q "{0}"'.format(home),
            "winget uninstall --id {0} -e".format(MIHOMO_WINGET_ID),
        ])
        problems = []
        if svc_state(MIHOMO_SVC):
            problems.append("服务仍在")
        if os.path.isfile(os.path.join(home, "mihomo.exe")):
            problems.append("安装目录未清空")
        if problems:
            raise RuntimeError("卸载不彻底：{0}（rc={1} {2}）".format(
                "; ".join(problems), rc, (out or "").strip()[-300:]))
        self.mihomo_log("ok", "服务与安装目录已清除，数据目录保留：{0}".format(mihomo_data_home()))

    def job_mihomo_latest(self):
        url = gh_url(self.ghproxy, "https://api.github.com/repos/MetaCubeX/mihomo/releases?per_page=20")
        self.mihomo_log("info", "查询：{0}".format(url))
        releases = get_github_json(self.ghproxy,
                                   "https://api.github.com/repos/MetaCubeX/mihomo/releases?per_page=20",
                                   self.mihomo_log)
        tag = ""
        for release in releases:
            if not release.get("prerelease") and not release.get("draft"):
                tag = release.get("tag_name", "")
                break
        if not tag:
            raise RuntimeError("没解析到最新 tag")
        self.mihomo_log("ok", "mihomo 最新版 {0}（winget 安装始终取最新；OpenWrt 模板版本 v{1}）".format(
            tag, MIHOMO_CORE_VER))

    def build_dotfiles_block(self, parent):
        frame = ttk.LabelFrame(parent, text="dotfile 管理", padding=10)
        frame.pack(fill="both", expand=True, padx=10, pady=10)

        head = ttk.Frame(frame)
        head.pack(fill="x")
        ttk.Label(head, text="备份 = 系统文件覆盖仓库文件；恢复 = 仓库文件覆盖系统文件", style="Desc.TLabel").pack(side="left")
        ttk.Button(head, text="刷新", command=self.refresh_dotfiles).pack(side="right")

        wrap = ttk.Frame(frame)
        wrap.pack(fill="both", expand=True, pady=(10, 0))
        self.dot_tree = ttk.Treeview(wrap, columns=("target", "repo", "state"), show="tree headings", selectmode="browse")
        self.dot_tree.heading("#0", text="名称")
        self.dot_tree.column("#0", width=190, anchor="w")
        self.dot_tree.heading("target", text="系统文件")
        self.dot_tree.column("target", width=380, anchor="w")
        self.dot_tree.heading("repo", text="仓库文件（相对仓库根目录）")
        self.dot_tree.column("repo", width=300, anchor="w")
        self.dot_tree.heading("state", text="状态")
        self.dot_tree.column("state", width=200, anchor="w")
        scroll = ttk.Scrollbar(wrap, orient="vertical", command=self.dot_tree.yview)
        self.dot_tree.configure(yscrollcommand=scroll.set)
        self.dot_tree.pack(side="left", fill="both", expand=True)
        scroll.pack(side="right", fill="y")
        self.dot_tree.tag_configure("ok", foreground="#1a7f37")
        self.dot_tree.tag_configure("bad", foreground="#a8071a")
        self.dot_tree.bind("<Double-1>", self.on_dot_double_click)
        self.dot_tree.bind("<<TreeviewSelect>>", lambda _e: self.set_status(
            "双击“系统文件”列打开配置所在目录，双击“仓库文件”列打开仓库文件位置"))

        row = ttk.Frame(frame)
        row.pack(fill="x", pady=(10, 0))
        ttk.Button(row, text="备份到仓库", command=lambda: self.dot_action("backup")).pack(side="left")
        ttk.Button(row, text="从仓库恢复", command=lambda: self.dot_action("restore")).pack(side="left", padx=6)
        ttk.Button(row, text="全部备份", command=lambda: self.dot_action("backup_all")).pack(side="right")
        ttk.Button(row, text="全部恢复", command=lambda: self.dot_action("restore_all")).pack(side="right", padx=6)

    def update_scoop_label(self):
        self.scoop_label_var.set("scoop 目录：{0}".format(self.scoop_dir))

    def open_preferences(self):
        dlg = tk.Toplevel(self)
        dlg.title("首选项")
        dlg.transient(self)
        dlg.resizable(False, False)
        body = ttk.Frame(dlg, padding=14)
        body.pack(fill="both", expand=True)

        scoop_var = tk.StringVar(value=self.scoop_dir)
        proxy_var = tk.StringVar(value=self.ghproxy)

        ttk.Label(body, text="scoop 目录").grid(row=0, column=0, sticky="w", pady=6)
        ttk.Entry(body, textvariable=scoop_var, width=52, font=FONT_MONO).grid(
            row=0, column=1, padx=8, sticky="we")
        ttk.Button(body, text="选择目录", command=lambda: self.pick_directory(scoop_var, scoop_var.get())).grid(
            row=0, column=2)

        ttk.Label(body, text="ghproxy 地址").grid(row=1, column=0, sticky="w", pady=6)
        ttk.Entry(body, textvariable=proxy_var, width=52, font=FONT_MONO).grid(
            row=1, column=1, padx=8, sticky="we")

        ttk.Label(body, text="保存到 {0}".format(STATE_PATH), style="Desc.TLabel").grid(
            row=2, column=0, columnspan=3, sticky="w", pady=(10, 0))

        row = ttk.Frame(body)
        row.grid(row=3, column=0, columnspan=3, sticky="e", pady=(10, 0))
        ttk.Button(row, text="关闭", command=dlg.destroy).pack(side="right", padx=(6, 0))
        ttk.Button(row, text="保存", command=lambda: self.save_preferences(
            scoop_var.get(), proxy_var.get(), dlg)).pack(side="right")

    def pick_directory(self, var, initial):
        chosen = filedialog.askdirectory(parent=self, initialdir=initial or self.scoop_dir)
        if chosen:
            var.set(chosen.replace("/", "\\"))

    def save_preferences(self, scoop_dir: str, ghproxy: str, dlg):
        scoop_dir = os.path.normpath(os.path.expandvars(scoop_dir.strip().strip('"')))
        if not scoop_dir or scoop_dir == ".":
            messagebox.showwarning(APP_TITLE, "scoop 目录不能为空")
            return
        ghproxy = ghproxy.strip() or DEFAULT_GHPROXY
        self.scoop_dir = scoop_dir
        self.ghproxy = ghproxy
        self.state_data["scoop_dir"] = scoop_dir
        self.state_data["ghproxy"] = ghproxy
        try:
            save_state(self.state_data)
        except OSError as exc:
            messagebox.showerror(APP_TITLE, "保存失败：{0}".format(exc))
            return
        self.update_scoop_label()
        dlg.destroy()
        self.set_status("首选项已保存")
        self.refresh_packages()

    def show_group(self):
        selection = self.group_list.curselection()
        if not selection:
            return
        group_title, pkgs = PACKAGE_GROUPS[selection[0]]
        self.pkg_tree.delete(*self.pkg_tree.get_children())
        for pkg in pkgs:
            state = self.pkg_states.get(pkg.title, "未检测")
            tag = "missing" if "未安装" in state else "installed"
            self.pkg_tree.insert("", "end", iid=pkg.title, text=pkg.title,
                                 values=(state, pkg.desc), tags=(tag,))
        self.current_pkg = None
        self.cmd_var.set("")

    def refresh_packages(self):
        scoop_dir = self.scoop_dir
        self.set_status("正在检测已安装软件 ...")
        self.scoop_state_var.set("scoop: {0}".format("已安装" if scoop_installed(scoop_dir) else "未安装"))

        self.pkg_gen += 1
        gen = self.pkg_gen

        def work():
            text = winget_list_text()
            apps = scoop_app_names(scoop_dir)
            states = {}
            for _group, pkgs in PACKAGE_GROUPS:
                for pkg in pkgs:
                    states[pkg.title] = pkg_state(pkg, text, scoop_dir, apps)
            self.pkg_queue.put((gen, text, states))

        threading.Thread(target=work, daemon=True).start()
        self.after(150, self.poll_pkg_result)

    def poll_pkg_result(self):
        try:
            gen, text, states = self.pkg_queue.get_nowait()
        except queue.Empty:
            self.after(150, self.poll_pkg_result)
            return
        if gen != self.pkg_gen:
            return
        self.apply_pkg_states(text, states)

    def apply_pkg_states(self, text, states):
        self.winget_text = text
        self.pkg_states = states
        self.show_group()
        self.update_altsnap_button()
        self.scoop_state_var.set("scoop: {0}".format("已安装" if scoop_installed(self.scoop_dir) else "未安装"))
        self.set_status("检测完成：{0}".format(time.strftime("%H:%M:%S")))

    def selected_pkg(self):
        selection = self.pkg_tree.selection()
        if not selection:
            return None
        title = selection[0]
        for _group, pkgs in PACKAGE_GROUPS:
            for pkg in pkgs:
                if pkg.title == title:
                    return pkg
        return None

    def on_pkg_select(self):
        self.current_pkg = self.selected_pkg()
        self.update_altsnap_button()

    def update_altsnap_button(self):
        pkg = self.current_pkg
        if pkg is None or pkg.title != ALTSNAP_TITLE:
            self.altsnap_startup_btn.pack_forget()
            return
        exists = task_exists(ALTSNAP_TASK)
        self.altsnap_startup_btn.configure(
            text="删除管理员开机启动" if exists else "配置管理员开机启动")
        self.altsnap_startup_btn.pack(side="left", padx=(18, 0))
        self.set_status("AltSnap：计划任务 {0} {1}".format(
            ALTSNAP_TASK, "已存在" if exists else "不存在"))

    def toggle_altsnap_startup(self):
        if task_exists(ALTSNAP_TASK):
            if not messagebox.askyesno(APP_TITLE, "删除计划任务 {0}？".format(ALTSNAP_TASK)):
                return
            rc, out = run_elevated_script(altsnap_delete_script())
            if rc != 0:
                messagebox.showerror(APP_TITLE, "删除失败：{0}".format(out.strip() or "已取消或权限不足"))
            self.update_altsnap_button()
            self.set_status("计划任务 {0}：{1}".format(
                ALTSNAP_TASK, "已删除" if not task_exists(ALTSNAP_TASK) else "仍存在"))
            return

        exe = find_altsnap_exe(self.scoop_dir)
        if not exe:
            messagebox.showwarning(APP_TITLE, "未找到 AltSnap.exe，请先安装 AltSnap")
            return
        if not messagebox.askyesno(APP_TITLE, "以管理员权限在登录时启动？\n{0}".format(exe)):
            return
        rc, out = run_elevated_script(altsnap_startup_script(exe))
        if rc != 0:
            messagebox.showerror(APP_TITLE, "创建失败：{0}".format(out.strip() or "已取消或权限不足"))
        self.update_altsnap_button()
        self.set_status("计划任务 {0}：{1}".format(
            ALTSNAP_TASK, "已创建" if task_exists(ALTSNAP_TASK) else "未创建"))

    def fill_cmd(self, action: str):
        pkg = self.current_pkg or self.selected_pkg()
        if pkg is None:
            messagebox.showinfo(APP_TITLE, "请先在列表中选择一个软件")
            return
        if action == "install":
            self.cmd_var.set(build_install_cmd(pkg, self.scoop_dir))
        else:
            self.cmd_var.set(build_uninstall_cmd(pkg, self.scoop_dir))
        self.set_status("{0}：{1}".format("安装命令" if action == "install" else "卸载命令", pkg.title))

    def copy_cmd(self):
        cmd = self.cmd_var.get().strip()
        if not cmd:
            self.set_status("没有可复制的命令")
            return
        self.clipboard_clear()
        self.clipboard_append(cmd)
        self.update_idletasks()
        self.set_status("命令已复制到剪贴板")

    def run_cmd(self):
        cmd = self.cmd_var.get().strip()
        if not cmd:
            self.set_status("没有可运行的命令")
            return
        run_ps_command(cmd)
        self.set_status("已在 PowerShell 窗口中执行")

    def refresh_feature_status(self):
        enabled = os.path.isfile(startup_shortcut())
        btn = getattr(self, "startup_toggle_btn", None)
        if btn is not None:
            btn.configure(text="禁止自动启动" if enabled else "允许自动启动")

    def feature_toggle_startup(self):
        if os.path.isfile(startup_shortcut()):
            self.feature_remove_startup()
        else:
            self.feature_add_startup()
        self.refresh_feature_status()

    def feature_start_onekey(self):
        script = onekey_script()
        if not os.path.isfile(script):
            messagebox.showerror(APP_TITLE, "找不到脚本：{0}".format(script))
            return
        exe = find_ahk_exe(self.scoop_dir)
        if not exe:
            messagebox.showerror(APP_TITLE, "未找到 AutoHotkey64.exe，请先安装 AutoHotkey")
            return
        subprocess.Popen([exe, script], cwd=SUPPLY_DIR)
        self.set_status("已启动 onekey_startup.ahk")

    def feature_add_startup(self):
        script = onekey_script()
        if not os.path.isfile(script):
            messagebox.showerror(APP_TITLE, "找不到脚本：{0}".format(script))
            return
        exe = find_ahk_exe(self.scoop_dir)
        if not exe:
            messagebox.showerror(APP_TITLE, "未找到 AutoHotkey64.exe，请先安装 AutoHotkey")
            return
        link = startup_shortcut()
        rc, out = create_startup_shortcut(link, exe, script, SUPPLY_DIR)
        self.refresh_feature_status()
        if os.path.isfile(link):
            self.set_status("已加入开机启动：{0}".format(link))
        else:
            messagebox.showerror(APP_TITLE, "创建快捷方式失败：{0}".format(out.strip()))

    def feature_remove_startup(self):
        link = startup_shortcut()
        if not os.path.isfile(link):
            self.set_status("开机启动中没有 onekey_startup.lnk")
            return
        try:
            os.remove(link)
        except OSError as exc:
            messagebox.showerror(APP_TITLE, "删除失败：{0}".format(exc))
            return
        self.refresh_feature_status()
        self.set_status("已移除开机启动")

    def feature_edit_onekey(self):
        script = onekey_script()
        if not os.path.isfile(script):
            messagebox.showerror(APP_TITLE, "找不到脚本：{0}".format(script))
            return
        subprocess.Popen(["notepad.exe", script])
        self.set_status("已用记事本打开 onekey_startup.ahk")

    def refresh_dotfiles(self):
        self.dot_tree.delete(*self.dot_tree.get_children())
        self.dot_rows = {}
        for item in DOTFILES:
            target = item.target_path()
            repo = item.repo_path()
            target_state = "系统有" if os.path.isfile(target) else "系统无"
            repo_state = "仓库有" if os.path.isfile(repo) else "仓库无"
            tag = "ok" if os.path.isfile(target) and os.path.isfile(repo) else "bad"
            text = "{0} / {1}".format(target_state, repo_state)
            if os.path.isfile(target) and os.path.isfile(repo):
                if os.path.getmtime(target) > os.path.getmtime(repo) + 1:
                    text += "（系统更新）"
                elif os.path.getmtime(repo) > os.path.getmtime(target) + 1:
                    text += "（仓库更新）"
            self.dot_rows[item.title] = item
            self.dot_tree.insert("", "end", iid=item.title, text=item.title,
                                 values=(target, item.repo_display(), text), tags=(tag,))
        self.set_status("dotfile 状态已刷新")

    def selected_dot(self):
        selection = self.dot_tree.selection()
        if not selection:
            messagebox.showinfo(APP_TITLE, "请先在列表中选择一项")
            return None
        return self.dot_rows.get(selection[0])

    def on_dot_double_click(self, event):
        row = self.dot_tree.identify_row(event.y)
        column = self.dot_tree.identify_column(event.x)
        if not row:
            return
        item = self.dot_rows.get(row)
        if item is None:
            return
        if column in ("#0", "#1"):
            path = item.target_path()
            label = "配置目录"
        elif column == "#2":
            path = item.repo_path()
            label = "仓库文件位置"
        else:
            return
        if not open_containing(path):
            messagebox.showinfo(APP_TITLE, "路径不存在：{0}".format(path))
            return
        self.set_status("已打开{0}：{1}".format(label, path))

    def dot_action(self, action: str):
        if action in ("backup_all", "restore_all"):
            verb = "备份（系统覆盖仓库）" if action == "backup_all" else "恢复（仓库覆盖系统）"
            if not messagebox.askyesno(APP_TITLE, "确认对全部 {0} 项执行{1}？".format(len(DOTFILES), verb)):
                return
            done = 0
            for item in DOTFILES:
                if self.dot_copy(item, "backup" if action == "backup_all" else "restore", quiet=True):
                    done += 1
            self.refresh_dotfiles()
            self.set_status("{0} 完成：{1}/{2}".format(verb, done, len(DOTFILES)))
            return

        item = self.selected_dot()
        if item is None:
            return
        if action == "backup":
            if self.dot_copy(item, "backup"):
                self.set_status("已备份到仓库：{0}".format(item.repo_path()))
        elif action == "restore":
            if self.dot_copy(item, "restore"):
                self.set_status("已从仓库恢复：{0}".format(item.target_path()))
        self.refresh_dotfiles()

    def dot_copy(self, item: DotFile, direction: str, quiet: bool = False) -> bool:
        target = item.target_path()
        repo = item.repo_path()
        try:
            if direction == "backup":
                if not os.path.isfile(target):
                    if not quiet:
                        messagebox.showwarning(APP_TITLE, "系统文件不存在：{0}".format(target))
                    return False
                copy_file(target, repo)
            else:
                if not os.path.isfile(repo):
                    if not quiet:
                        messagebox.showwarning(APP_TITLE, "仓库文件不存在：{0}".format(repo))
                    return False
                copy_file(repo, target)
            return True
        except OSError as exc:
            if not quiet:
                messagebox.showerror(APP_TITLE, "操作失败：{0}".format(exc))
            return False


def ps_quote(value: str) -> str:
    return value.replace("'", "''")


def create_startup_shortcut(link: str, exe: str, script: str, workdir: str):
    os.makedirs(os.path.dirname(link), exist_ok=True)
    ps = (
        "$w = New-Object -ComObject WScript.Shell; "
        "$s = $w.CreateShortcut('{link}'); "
        "$s.TargetPath = '{exe}'; "
        "$s.Arguments = '\"{script}\"'; "
        "$s.WorkingDirectory = '{work}'; "
        "$s.WindowStyle = 7; "
        "$s.Save()"
    ).format(link=ps_quote(link), exe=ps_quote(exe), script=ps_quote(script), work=ps_quote(workdir))
    return run_capture([find_powershell(), "-NoProfile", "-Command", ps])


def main():
    app = App()
    app.mainloop()


if __name__ == "__main__":
    main()
