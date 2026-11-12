# -*- coding: utf-8 -*-
"""win11tools main window"""

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
MIHOMO_TITLE = "mihomo"
MIHOMO_WINGET_ID = "MetaCubeX.Mihomo"
MIHOMO_CORE_VER = "1.19.33"
MIHOMO_UI_VER = "1.273.0"
GO_PROXY = "https://mirrors.aliyun.com/goproxy/,direct"
GO_SUMDB = "sum.golang.google.cn"
NODE_WINGET_ID = "OpenJS.NodeJS"
PNPM_WINGET_ID = "pnpm.pnpm"
GO_WINGET_ID = "GoLang.Go"
BUN_WINGET_ID = "Oven-sh.Bun"
WINGET_MANAGED_NOTE = "请使用 winget 管理"
APP_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(APP_DIR)
LOCAL_DOTFILES_DIR = os.path.join(APP_DIR, "win11.dotfiles")
STATE_PATH = os.path.join(APP_DIR, "win11tools.json")

FONT_UI = ("Microsoft YaHei UI", 10)
FONT_UI_BOLD = ("Microsoft YaHei UI", 10, "bold")
FONT_SMALL = ("Microsoft YaHei UI", 9)
FONT_TITLE = ("Microsoft YaHei UI", 11, "bold")
FONT_HEAD = ("Microsoft YaHei UI", 14, "bold")
FONT_MONO = ("Consolas", 10)

COLOR_BG = "#f3f4f6"
COLOR_PANEL = "#ffffff"
COLOR_FG = "#1f2328"
COLOR_MUTED = "#5b6470"
COLOR_LINE = "#d8dce2"
COLOR_ACCENT = "#2f6feb"
COLOR_ACCENT_DARK = "#1f5bd0"
COLOR_SELECT = "#dce8ff"
COLOR_OK = "#1a7f37"
COLOR_WARN = "#b26a00"
COLOR_ERR = "#c62828"

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


def abbreviate_path(path: str) -> str:
    if not path:
        return ""
    candidates = []
    for name in ("LOCALAPPDATA", "APPDATA", "USERPROFILE"):
        value = os.environ.get(name, "")
        if value:
            candidates.append((name, value.rstrip("\\/")))
    home = os.path.expanduser("~").rstrip("\\/")
    if home and all(value.lower() != home.lower() for _name, value in candidates):
        candidates.append(("USERPROFILE", home))
    candidates.sort(key=lambda item: len(item[1]), reverse=True)
    low = path.lower()
    for name, value in candidates:
        prefix = value.lower()
        if low == prefix:
            return "<{0}>".format(name)
        if low.startswith(prefix + "\\") or low.startswith(prefix + "/"):
            return "<{0}>{1}".format(name, path[len(value):])
    return path


@dataclass(frozen=True)
class Package:
    title: str
    desc: str
    backend: str
    names: tuple[str, ...]
    extra_bucket: str = ""
    special: str = ""
    scoop_alias: str = ""
    managed_by: str = ""
    kind_label: str = ""
    panel: str = ""
    env: tuple[tuple[str, str], ...] = ()
    env_paths: tuple[str, ...] = ()
    env_cleanup: tuple[str, ...] = ()
    env_cleanup_paths: tuple[str, ...] = ()

    def kind(self) -> str:
        return self.kind_label or self.backend


@dataclass(frozen=True)
class DotFile:
    target: str
    repo: str

    def target_path(self) -> str:
        return os.path.expandvars(self.target)

    def target_display(self) -> str:
        return abbreviate_path(self.target_path())

    def repo_path(self) -> str:
        return os.path.normpath(os.path.join(APP_DIR, self.repo))

    def repo_display(self) -> str:
        return os.path.relpath(self.repo_path(), REPO_DIR)


SOFTWARE = {
    "系统工具": (
        Package("PowerShell 7", "Microsoft.PowerShell", "winget", ("Microsoft.PowerShell",)),
        Package("Coreutils", "Microsoft.Coreutils", "winget", ("Microsoft.Coreutils",)),
        Package("Seelen UI", "Seelen.SeelenUI", "winget", ("Seelen.SeelenUI",)),
        Package("DISM++", "ChuyuTeam.DISM++", "winget", ("ChuyuTeam.DISM++",), scoop_alias="dismplusplus"),
        Package("Nushell", "Nushell.Nushell", "winget", ("Nushell.Nushell",)),
        Package("Helix", "Helix.Helix", "winget", ("Helix.Helix",)),
        Package("noctty", "AmanThanvi.noctty", "winget", ("AmanThanvi.noctty",)),
        Package("7-Zip", "7zip.7zip", "winget", ("7zip.7zip",)),
        Package("Git", "Git.Git", "winget", ("Git.Git",)),
        Package("lazygit", "JesseDuffield.lazygit", "winget", ("JesseDuffield.lazygit",)),
        Package(ALTSNAP_TITLE, "AltSnap.AltSnap", "winget", ("AltSnap.AltSnap",), panel="altsnap"),
    ),
    "开发环境": (
        Package("Node.js", "nodejs 由 winget 管理", "winget", (NODE_WINGET_ID,),
                managed_by="winget", env_paths=(r"%APPDATA%\npm",)),
        Package("pnpm", "pnpm 由 winget 管理", "winget", (PNPM_WINGET_ID,),
                managed_by="winget", env=(("PNPM_HOME", r"%LOCALAPPDATA%\pnpm"),),
                env_paths=(r"%LOCALAPPDATA%\pnpm\bin",)),
        Package("golang", "go 工具链由 winget 管理", "winget", (GO_WINGET_ID,),
                managed_by="winget", env=(("GOPROXY", GO_PROXY), ("GOSUMDB", GO_SUMDB)),
                env_cleanup=("GOPATH", "GOROOT", "GOBIN", "GOFLAGS", "GOPRIVATE"),
                env_cleanup_paths=(r"%USERPROFILE%\go\bin",)),
        Package("bun", "bun 运行时与包管理器", "winget", (BUN_WINGET_ID,),
                managed_by="winget", env=(("BUN_INSTALL", r"%USERPROFILE%\.bun"),),
                env_paths=(r"%USERPROFILE%\.bun\bin",)),
        Package("rustup", "Rust 工具链", "scoop", ("rustup",)),
        Package("flutter", "Flutter SDK，需要 extras bucket", "scoop", ("flutter",), extra_bucket="extras"),
        Package("zig", "Zig 工具链", "scoop", ("zig",)),
    ),
    "常用软件": (
        Package("Chrome", "googlechrome", "scoop", ("googlechrome",)),
        Package("Obsidian", "obsidian", "scoop", ("obsidian",)),
        Package("QQ NT", "qq-nt", "scoop", ("qq-nt",)),
        Package("Telegram", "telegram", "scoop", ("telegram",)),
    ),
    "scoop 自身": (
        Package("scoop", "安装到上面填写的 scoop 目录", "scoop", ("scoop",), special="scoop_self",
                kind_label="自定义"),
    ),
    "mihomo 服务": (
        Package(MIHOMO_TITLE, "MetaCubeX.Mihomo 代理核心与服务", "winget", (MIHOMO_WINGET_ID,),
                kind_label="自定义", panel="mihomo"),
    ),
}

PKG_INDEX = {pkg.title: pkg for pkgs in SOFTWARE.values() for pkg in pkgs}

DOTFILES = {
    "noctty config.ghostty": DotFile(r"%LOCALAPPDATA%\noctty\config.ghostty",
                                     r"win11.dotfiles\noctty_config.ghostty"),
    "nvim init.lua": DotFile(r"%LOCALAPPDATA%\nvim\init.lua",
                             r"win11.dotfiles\nvim_win_init.lua"),
    "helix config.toml": DotFile(r"%APPDATA%\helix\config.toml",
                                 r"..\dotfiles\helix_config.toml"),
    "helix languages.toml": DotFile(r"%APPDATA%\helix\languages.toml",
                                    r"..\dotfiles\helix_languages.toml"),
    "pi settings.json": DotFile(r"%USERPROFILE%\.pi\agent\settings.json",
                                r"..\dotfiles\pi_settings.json"),
    "pi models.json": DotFile(r"%USERPROFILE%\.pi\agent\models.json",
                              r"..\dotfiles\pi_models.json"),
    "pi goal.json": DotFile(r"%USERPROFILE%\.pi\agent\pi-goal.json",
                            r"..\dotfiles\pi_goal.json"),
    "zed settings.json": DotFile(r"%APPDATA%\Zed\settings.json",
                                 r"win11.dotfiles\zed_config.json"),
    "seelen-ui settings.json": DotFile(r"%APPDATA%\com.seelen.seelen-ui\settings.json",
                                      r"win11.dotfiles\seelen-ui_setting.json"),
}


def build_search_rows():
    rows = []
    for group, pkgs in SOFTWARE.items():
        for pkg in pkgs:
            keys = [group, pkg.title, pkg.desc, pkg.kind(), pkg.backend]
            keys.extend(pkg.names)
            rows.append(("常用软件", "{0}>{1}".format(group, pkg.title), " ".join(keys).lower()))
    for title, item in DOTFILES.items():
        keys = [title, item.target, item.target_display(), item.repo_display()]
        rows.append(("dotfile", title, " ".join(keys).lower()))
    return rows

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


def set_user_env_cmd(name: str, value: str) -> str:
    return '[Environment]::SetEnvironmentVariable("{0}", "{1}", "User")'.format(name, value)


def append_user_path_cmd(path: str) -> str:
    return (
        "$userPath = [Environment]::GetEnvironmentVariable('Path', 'User'); "
        "$paths = @($userPath -split ';' | Where-Object {{ $_ -and $_ -ne '{0}' }}); "
        "if ($paths -notcontains '{0}') {{ $paths += '{0}' }}; "
        "[Environment]::SetEnvironmentVariable('Path', ($paths -join ';'), 'User')"
    ).format(path)


def remove_user_env_cmd(name: str) -> str:
    return '[Environment]::SetEnvironmentVariable("{0}", $null, "User")'.format(name)


def remove_user_path_cmd(path: str) -> str:
    return (
        "$userPath = [Environment]::GetEnvironmentVariable('Path', 'User'); "
        "$paths = @($userPath -split ';' | Where-Object {{ $_ -and $_ -ne '{0}' }}); "
        "[Environment]::SetEnvironmentVariable('Path', ($paths -join ';'), 'User')"
    ).format(path)


def env_layout(pkg: Package):
    envs = {name: os.path.expandvars(value) for name, value in pkg.env}
    paths = [os.path.expandvars(path) for path in pkg.env_paths]
    return envs, paths


def env_apply_cmd(pkg: Package) -> str:
    envs, paths = env_layout(pkg)
    parts = [set_user_env_cmd(name, value) for name, value in envs.items()]
    parts.extend(append_user_path_cmd(path) for path in paths)
    parts.extend('$env:{0} = "{1}"'.format(name, value) for name, value in envs.items())
    if paths:
        joined = ";".join(paths)
        parts.append('$env:Path = "{0};" + $env:Path'.format(joined))
    return "; ".join(parts)


def env_cleanup_cmd(pkg: Package) -> str:
    envs, paths = env_layout(pkg)
    paths = paths + [os.path.expandvars(path) for path in pkg.env_cleanup_paths]
    parts = [remove_user_path_cmd(path) for path in paths]
    parts.extend(remove_user_env_cmd(name) for name in envs)
    parts.extend(remove_user_env_cmd(name) for name in pkg.env_cleanup)
    return "; ".join(parts)


def winget_install_cmd(pkg: Package) -> str:
    parts = [
        "winget install --id {0} -e --source winget "
        "--accept-package-agreements --accept-source-agreements".format(pkg_id)
        for pkg_id in pkg.names
    ]
    env_cmd = env_apply_cmd(pkg)
    if env_cmd:
        parts.append(env_cmd)
    return "; ".join(parts)


def build_install_cmd(pkg: Package, scoop_dir: str) -> str:
    if pkg.backend == "winget":
        return winget_install_cmd(pkg)
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
    if pkg.panel == "mihomo":
        return mihomo_purge_cmd()
    if pkg.backend == "winget":
        parts = ["winget uninstall --id {0} -e".format(n) for n in pkg.names]
        cleanup = env_cleanup_cmd(pkg)
        if cleanup:
            parts.append(cleanup)
        return "; ".join(parts)
    body = "scoop uninstall " + " ".join(pkg.names)
    return scoop_prefix(scoop_dir, body)


def mihomo_purge_cmd() -> str:
    parts = [
        "net stop {0}".format(MIHOMO_SVC),
        "sc.exe delete {0}".format(MIHOMO_SVC),
        "winget uninstall --id {0} -e".format(MIHOMO_WINGET_ID),
        'Remove-Item "{0}" -Recurse -Force -ErrorAction SilentlyContinue'.format(mihomo_home()),
        'Remove-Item "{0}" -Recurse -Force -ErrorAction SilentlyContinue'.format(mihomo_data_home()),
    ]
    return "; ".join(parts)


def mihomo_panel_cmd(proxy: str) -> str:
    url = gh_url(proxy, "MetaCubeX/metacubexd/archive/refs/heads/gh-pages.zip")
    return (
        '$u = "{url}"; $t = "$env:TEMP/mihomo-ui.zip"; $tmp = "$env:TEMP/mihomo-ui"; '
        '$d = "$env:LOCALAPPDATA/mihomo/ui"; '
        'New-Item -ItemType Directory -Force -Path (Split-Path $d) | Out-Null; '
        'Invoke-WebRequest $u -OutFile $t; '
        'Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue; '
        'Expand-Archive $t $tmp -Force; '
        'Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue; '
        'Move-Item (Get-ChildItem $tmp | Select-Object -First 1) $d; '
        'Remove-Item $t; Write-Output "panel: $d"'
    ).format(url=url)


def mihomo_service_cmd(scoop_dir: str) -> str:
    exe = find_mihomo_exe() or "mihomo.exe"
    nssm = find_nssm(scoop_dir) or "nssm"
    data = mihomo_data_home()
    cfg = ensure_mihomo_cfg() or os.path.join(data, "config.yaml")
    return (
        "\"{nssm}\" install {svc} \"{exe}\"; "
        "\"{nssm}\" set {svc} AppDirectory \"{data}\"; "
        "\"{nssm}\" set {svc} AppParameters '-d \"{data}\" -f \"{cfg}\"'; "
        "\"{nssm}\" set {svc} Start SERVICE_AUTO_START; "
        "sc.exe start {svc}"
    ).format(nssm=nssm, svc=MIHOMO_SVC, exe=exe, data=data, cfg=cfg)


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
        present = [n for n in pkg.names if n.lower() in low]
        if len(present) == len(pkg.names):
            return "winget 已安装"
        if present:
            return "winget 部分安装 {0}/{1}".format(len(present), len(pkg.names))
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
    return os.path.join(APP_DIR, "onekey_startup.ahk")


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


class ScrollFrame(ttk.Frame):
    def __init__(self, parent):
        super().__init__(parent)
        self.canvas = tk.Canvas(self, bg=COLOR_BG, highlightthickness=0, borderwidth=0,
                                xscrollincrement=24, yscrollincrement=24)
        self.vsb = ttk.Scrollbar(self, orient="vertical", command=self.canvas.yview)
        self.hsb = ttk.Scrollbar(self, orient="horizontal", command=self.canvas.xview)
        self.canvas.configure(yscrollcommand=self.vsb.set, xscrollcommand=self.hsb.set)
        self.canvas.grid(row=0, column=0, sticky="nsew")
        self.vsb.grid(row=0, column=1, sticky="ns")
        self.hsb.grid(row=1, column=0, sticky="we")
        self.rowconfigure(0, weight=1)
        self.columnconfigure(0, weight=1)
        self.inner = ttk.Frame(self.canvas)
        self._window = self.canvas.create_window((0, 0), window=self.inner, anchor="nw")
        self.inner.bind("<Configure>", self._sync)
        self.canvas.bind("<Configure>", self._sync)
        self.canvas.bind("<Enter>", self._bind_wheel)
        self.canvas.bind("<Leave>", self._unbind_wheel)

    def _sync(self, _event=None):
        canvas_width = self.canvas.winfo_width()
        canvas_height = self.canvas.winfo_height()
        if canvas_width <= 1:
            return
        width = max(canvas_width, self.inner.winfo_reqwidth())
        height = max(canvas_height, self.inner.winfo_reqheight())
        self.canvas.itemconfigure(self._window, width=width, height=height)
        self.canvas.configure(scrollregion=(0, 0, width, height))

    def _bind_wheel(self, _event=None):
        self.canvas.bind_all("<MouseWheel>", self._on_wheel)
        self.canvas.bind_all("<Shift-MouseWheel>", self._on_shift_wheel)

    def _unbind_wheel(self, _event=None):
        self.canvas.unbind_all("<MouseWheel>")
        self.canvas.unbind_all("<Shift-MouseWheel>")

    def _on_wheel(self, event):
        self.canvas.yview_scroll(int(-event.delta / 120), "units")

    def _on_shift_wheel(self, event):
        self.canvas.xview_scroll(int(-event.delta / 120), "units")


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(APP_TITLE)
        self.geometry("1440x900")
        self.minsize(1040, 660)
        self.state_data = load_state()
        self.scoop_dir = self.state_data.get("scoop_dir") or default_scoop_dir()
        self.ghproxy = self.state_data.get("ghproxy") or DEFAULT_GHPROXY
        self.winget_text = ""
        self.current_pkg = None
        self.pkg_states = {}
        self.pkg_queue = queue.Queue()
        self.pkg_gen = 0
        self.altsnap_startup_btn = None
        self.setup_style()
        self.build_ui()
        self.refresh_packages()
        self.refresh_dotfiles()
        self.refresh_feature_status()
        self.set_status("就绪")

    def setup_style(self):
        style = ttk.Style(self)
        try:
            style.theme_use("clam")
        except tk.TclError:
            pass
        self.configure(bg=COLOR_BG)
        style.configure(".", font=FONT_UI, background=COLOR_BG, foreground=COLOR_FG)
        style.configure("TFrame", background=COLOR_BG)
        style.configure("TLabel", background=COLOR_BG, foreground=COLOR_FG)
        style.configure("Head.TLabel", font=FONT_HEAD, background=COLOR_BG, foreground=COLOR_FG)
        style.configure("Title.TLabel", font=FONT_TITLE, background=COLOR_BG, foreground=COLOR_FG)
        style.configure("Value.TLabel", font=FONT_UI_BOLD, background=COLOR_BG, foreground=COLOR_FG)
        style.configure("Muted.TLabel", font=FONT_SMALL, background=COLOR_BG, foreground=COLOR_MUTED)
        style.configure("Desc.TLabel", font=FONT_SMALL, background=COLOR_BG, foreground=COLOR_MUTED)
        style.configure("Group.TLabel", font=FONT_UI_BOLD, background=COLOR_BG, foreground=COLOR_ACCENT)
        style.configure("TLabelframe", background=COLOR_BG, bordercolor=COLOR_LINE,
                        relief="solid", borderwidth=1)
        style.configure("TLabelframe.Label", background=COLOR_BG, foreground=COLOR_ACCENT,
                        font=FONT_UI_BOLD)
        style.configure("TButton", font=FONT_UI, padding=(11, 5), background=COLOR_PANEL,
                        bordercolor="#c9d0da", focusthickness=0, relief="flat")
        style.map("TButton",
                  background=[("pressed", "#dce8ff"), ("active", "#eaf0fb")],
                  bordercolor=[("active", COLOR_ACCENT)],
                  foreground=[("disabled", "#9aa3ad")])
        style.configure("Accent.TButton", background=COLOR_ACCENT, foreground="#ffffff",
                        bordercolor=COLOR_ACCENT)
        style.map("Accent.TButton",
                  background=[("pressed", COLOR_ACCENT_DARK), ("active", COLOR_ACCENT_DARK),
                              ("disabled", "#9db7ef")],
                  foreground=[("disabled", "#f2f6ff")])
        style.configure("TEntry", fieldbackground=COLOR_PANEL, bordercolor="#c9d0da",
                        padding=5, insertcolor=COLOR_FG)
        style.configure("TNotebook", background=COLOR_BG, borderwidth=0,
                        tabmargins=(0, 4, 0, 0))
        style.configure("TNotebook.Tab", font=FONT_UI, padding=(20, 8),
                        background="#e4e8ef", foreground=COLOR_MUTED, borderwidth=0)
        style.map("TNotebook.Tab",
                  background=[("selected", COLOR_PANEL)],
                  foreground=[("selected", COLOR_ACCENT)],
                  bordercolor=[("selected", COLOR_ACCENT)],
                  expand=[("selected", (0, 0, 0, 0)), ("!selected", (0, 0, 0, 0))],
                  padding=[("selected", (20, 8)), ("!selected", (20, 8))])
        style.configure("Treeview", font=FONT_UI, rowheight=26, background=COLOR_PANEL,
                        fieldbackground=COLOR_PANEL, borderwidth=0)
        style.configure("Treeview.Heading", font=FONT_UI_BOLD, background="#eef1f6",
                        foreground=COLOR_FG, relief="flat", padding=(8, 6))
        style.map("Treeview.Heading", background=[("active", "#e2e7ef")])
        style.map("Treeview", background=[("selected", COLOR_SELECT)],
                  foreground=[("selected", COLOR_FG)])
        style.configure("TScrollbar", background="#e4e8ef", troughcolor=COLOR_BG,
                        bordercolor=COLOR_BG, arrowcolor=COLOR_MUTED)
        style.configure("TProgressbar", troughcolor="#e8ecf2", background=COLOR_ACCENT,
                        borderwidth=0, thickness=6)
        style.configure("Status.TFrame", background="#e8ebf0")
        style.configure("Status.TLabel", background="#e8ebf0", foreground=COLOR_MUTED)
        style.configure("StatusValue.TLabel", background="#e8ebf0", foreground=COLOR_FG,
                        font=FONT_SMALL)

    def build_ui(self):
        self.build_status_bar()

        self.scroller = ScrollFrame(self)
        self.scroller.pack(fill="both", expand=True)
        content = self.scroller.inner

        self.build_header(content)
        self.notebook = ttk.Notebook(content)
        self.notebook.pack(fill="both", expand=True, padx=12, pady=(4, 0))
        self.build_log_panel(content)

        self.build_packages_tab(self.notebook)
        self.build_features_tab(self.notebook)
        self.build_dotfiles_tab(self.notebook)
        self.build_search_tab(self.notebook)

    def build_status_bar(self):
        bar = ttk.Frame(self, style="Status.TFrame", padding=(14, 5))
        bar.pack(side="bottom", fill="x")
        self.status_var = tk.StringVar(value="就绪")
        ttk.Label(bar, textvariable=self.status_var, style="Status.TLabel",
                  anchor="w").pack(side="left", fill="x", expand=True)
        self.scoop_state_var = tk.StringVar(value="")
        ttk.Label(bar, textvariable=self.scoop_state_var, style="StatusValue.TLabel",
                  anchor="e").pack(side="right")

    def build_header(self, parent):
        head = ttk.Frame(parent, padding=(14, 12, 14, 2))
        head.pack(side="top", fill="x")
        ttk.Label(head, text=APP_TITLE, style="Head.TLabel").pack(side="left")
        ttk.Label(head, text="软件安装 · 功能开关 · dotfile 同步", style="Muted.TLabel").pack(
            side="left", padx=(12, 0), pady=(8, 0))
        ttk.Button(head, text="首选项", command=self.open_preferences).pack(side="right")

    def build_log_panel(self, parent):
        frame = ttk.LabelFrame(parent, text="日志", padding=(10, 8))
        frame.pack(fill="x", padx=12, pady=(8, 12))

        head = ttk.Frame(frame)
        head.pack(fill="x")
        ttk.Button(head, text="复制日志", command=self.copy_log).pack(side="right")
        ttk.Button(head, text="清空", command=self.clear_log).pack(side="right", padx=(0, 6))

        wrap = ttk.Frame(frame)
        wrap.pack(fill="both", expand=True, pady=(8, 0))
        self.log_text = tk.Text(wrap, width=1, height=6, wrap="none", font=FONT_MONO, state="disabled",
                                bg=COLOR_PANEL, relief="flat", highlightthickness=1,
                                highlightbackground=COLOR_LINE, padx=8, pady=6)
        scroll = ttk.Scrollbar(wrap, orient="vertical", command=self.log_text.yview)
        self.log_text.configure(yscrollcommand=scroll.set)
        self.log_text.pack(side="left", fill="both", expand=True)
        scroll.pack(side="right", fill="y")
        for level, color in (("info", COLOR_FG), ("ok", COLOR_OK),
                             ("warn", COLOR_WARN), ("error", COLOR_ERR)):
            self.log_text.tag_config(level, foreground=color)

    def copy_log(self):
        text = self.log_text.get("1.0", "end").strip()
        if not text:
            self.set_status("日志为空")
            return
        self.clipboard_clear()
        self.clipboard_append(text)
        self.update_idletasks()
        self.set_status("日志已复制到剪贴板")

    def clear_log(self):
        self.log_text.configure(state="normal")
        self.log_text.delete("1.0", "end")
        self.log_text.configure(state="disabled")
        self.set_status("日志已清空")

    def set_status(self, msg: str):
        self.status_var.set(msg)

    def build_packages_tab(self, parent):
        frame = ttk.Frame(parent, padding=12)
        parent.add(frame, text="常用软件")

        top = ttk.Frame(frame)
        top.pack(fill="x")
        self.scoop_label_var = tk.StringVar()
        ttk.Label(top, textvariable=self.scoop_label_var, style="Muted.TLabel").pack(
            side="left", pady=(4, 0))
        ttk.Button(top, text="刷新检测", style="Accent.TButton",
                   command=self.refresh_packages).pack(side="right")
        self.update_scoop_label()

        body = ttk.Panedwindow(frame, orient="horizontal")
        body.pack(fill="both", expand=True, pady=(10, 0))

        left = ttk.Frame(body)
        body.add(left, weight=1)
        ttk.Label(left, text="分区", style="Group.TLabel").pack(anchor="w", pady=(0, 6))
        self.group_list = tk.Listbox(left, exportselection=False, font=FONT_UI, activestyle="none",
                                     bg=COLOR_PANEL, relief="flat", highlightthickness=1,
                                     highlightbackground=COLOR_LINE, highlightcolor=COLOR_ACCENT,
                                     selectbackground=COLOR_SELECT, selectforeground=COLOR_FG,
                                     borderwidth=0, width=16)
        self.group_list.pack(side="left", fill="both", expand=True)
        for title in SOFTWARE:
            self.group_list.insert("end", "  " + title)
        self.group_list.bind("<<ListboxSelect>>", lambda _e: self.show_group())

        right = ttk.Frame(body, padding=(12, 0, 0, 0))
        body.add(right, weight=4)
        ttk.Label(right, text="软件列表（双击可选行生成安装命令）", style="Group.TLabel").pack(
            anchor="w", pady=(0, 6))
        tree_wrap = ttk.Frame(right)
        tree_wrap.pack(fill="both", expand=True)
        self.pkg_tree = ttk.Treeview(tree_wrap, columns=("name", "kind", "state", "desc"),
                                     show="headings", selectmode="browse")
        self.pkg_tree.heading("name", text="名称")
        self.pkg_tree.column("name", width=200, anchor="w")
        self.pkg_tree.heading("kind", text="类型")
        self.pkg_tree.column("kind", width=90, anchor="w")
        self.pkg_tree.heading("state", text="状态")
        self.pkg_tree.column("state", width=150, anchor="w")
        self.pkg_tree.heading("desc", text="说明")
        self.pkg_tree.column("desc", width=420, anchor="w")
        scroll = ttk.Scrollbar(tree_wrap, orient="vertical", command=self.pkg_tree.yview)
        self.pkg_tree.configure(yscrollcommand=scroll.set)
        self.pkg_tree.pack(side="left", fill="both", expand=True)
        scroll.pack(side="right", fill="y")
        self.pkg_tree.bind("<<TreeviewSelect>>", lambda _e: self.on_pkg_select())
        self.pkg_tree.bind("<Double-1>", lambda _e: self.fill_cmd("install"))
        self.pkg_tree.tag_configure("installed", foreground=COLOR_OK)
        self.pkg_tree.tag_configure("missing", foreground="#a8071a")

        cmd_box = ttk.LabelFrame(frame, text="命令（可编辑后复制或运行）", padding=10)
        cmd_box.pack(fill="x", pady=(12, 0))
        self.cmd_var = tk.StringVar()
        ttk.Entry(cmd_box, textvariable=self.cmd_var, font=FONT_MONO).pack(fill="x")
        row = ttk.Frame(cmd_box)
        row.pack(fill="x", pady=(10, 0))
        ttk.Button(row, text="生成安装命令", style="Accent.TButton",
                   command=lambda: self.fill_cmd("install")).pack(side="left")
        ttk.Button(row, text="生成卸载命令", command=lambda: self.fill_cmd("uninstall")).pack(
            side="left", padx=6)
        ttk.Button(row, text="复制", command=self.copy_cmd).pack(side="left")
        ttk.Button(row, text="运行 (PowerShell)", command=self.run_cmd).pack(side="left", padx=6)
        ttk.Label(row, text="安装/卸载完成后点“刷新检测”更新状态", style="Desc.TLabel").pack(side="right")

        self.extra_frame = ttk.Frame(cmd_box)

        self.group_list.selection_set(0)
        self.show_group()

    def build_features_tab(self, parent):
        frame = ttk.Frame(parent, padding=12)
        parent.add(frame, text="功能")

        feature = ttk.LabelFrame(frame, text="onekey 快捷启动", padding=12)
        feature.pack(fill="x")
        grid = ttk.Frame(feature)
        grid.pack(fill="x", anchor="nw")
        for row, item in enumerate(FEATURE_ROWS):
            ttk.Label(grid, text=item[0], style="Value.TLabel").grid(
                row=row, column=0, sticky="w", padx=(0, 20), pady=6)
            for col, (label, method) in enumerate(item[1:], start=1):
                style = "Accent.TButton" if col == 1 else "TButton"
                btn = ttk.Button(grid, text=label, width=16, style=style, command=getattr(self, method))
                btn.grid(row=row, column=col, sticky="w", padx=(0, 8), pady=6)
                if method == "feature_toggle_startup":
                    self.startup_toggle_btn = btn
        ttk.Label(feature, text="自动启动写入当前用户启动文件夹的 onekey_startup.lnk",
                  style="Desc.TLabel").pack(anchor="w", pady=(10, 0))

    def log_line(self, level, text):
        self.log_text.configure(state="normal")
        self.log_text.insert("end", "[{0}] [{1}] {2}\n".format(time.strftime("%H:%M:%S"), level, text), level)
        self.log_text.see("end")
        self.log_text.configure(state="disabled")

    def mihomo_status_text(self) -> str:
        exe = find_mihomo_exe()
        core = "未安装"
        if exe:
            version = mihomo_core_version()
            core = "已安装 {0}".format(version) if version else "已安装"
        state = svc_state(MIHOMO_SVC)
        service = "运行中" if state == "RUNNING" else ("已停止" if state == "STOPPED" else "未注册")
        cfg = mihomo_cfg_path()
        return "核心: {0}    服务: {1}    面板: {2}    配置: {3}（{4}）".format(
            core, service, mihomo_panel_ver(), cfg, "存在" if os.path.isfile(cfg) else "不存在")

    def update_selection_actions(self):
        for child in self.extra_frame.winfo_children():
            child.destroy()
        pkg = self.current_pkg
        if pkg is None:
            self.extra_frame.pack_forget()
            return
        if pkg.managed_by == "winget":
            self.extra_frame.pack(fill="x", pady=(10, 0))
            ttk.Label(self.extra_frame, text=WINGET_MANAGED_NOTE, style="Value.TLabel").pack(anchor="w")
            return
        if not pkg.panel:
            self.extra_frame.pack_forget()
            return
        self.extra_frame.pack(fill="x", pady=(10, 0))
        if pkg.panel == "altsnap":
            self.build_altsnap_actions()
        else:
            self.build_mihomo_actions()

    def build_altsnap_actions(self):
        self.altsnap_startup_btn = ttk.Button(self.extra_frame, text="配置管理员开机启动",
                                              command=self.toggle_altsnap_startup)
        self.altsnap_startup_btn.pack(side="left")
        self.refresh_altsnap_button()

    def refresh_altsnap_button(self):
        if self.altsnap_startup_btn is None:
            return
        exists = task_exists(ALTSNAP_TASK)
        self.altsnap_startup_btn.configure(
            text="删除管理员开机启动" if exists else "配置管理员开机启动")
        self.set_status("AltSnap：计划任务 {0} {1}".format(
            ALTSNAP_TASK, "已存在" if exists else "不存在"))

    def build_mihomo_actions(self):
        ttk.Label(self.extra_frame, text=self.mihomo_status_text(),
                  style="Muted.TLabel").pack(anchor="w")
        buttons = ttk.Frame(self.extra_frame)
        buttons.pack(fill="x", pady=(6, 0))
        running = svc_state(MIHOMO_SVC) == "RUNNING"
        specs = (
            ("安装 / 更新面板", self.cmd_mihomo_panel, True),
            ("注册服务", self.cmd_mihomo_service, False),
            ("停止服务" if running else "启动服务", self.cmd_mihomo_toggle_service, False),
            ("删除服务", self.cmd_mihomo_delete_service, False),
            ("打开配置", self.open_mihomo_cfg, False),
            ("打开数据目录", lambda: self.open_dir(mihomo_data_home()), False),
            ("打开安装目录", lambda: self.open_dir(mihomo_home()), False),
            ("OpenWrt 命令", self.show_mihomo_openwrt, False),
        )
        for idx, (text, command, accent) in enumerate(specs):
            btn = ttk.Button(buttons, text=text, command=command,
                             style="Accent.TButton" if accent else "TButton")
            btn.grid(row=idx // 4, column=idx % 4, sticky="we", padx=3, pady=3)
        for col in range(4):
            buttons.columnconfigure(col, weight=1)

    def set_cmd(self, command: str, label: str):
        self.cmd_var.set(command)
        self.set_status("{0}：命令已生成，可编辑后复制或运行".format(label))

    def cmd_mihomo_panel(self):
        self.set_cmd(mihomo_panel_cmd(self.ghproxy), "mihomo 安装 / 更新面板")

    def cmd_mihomo_service(self):
        self.set_cmd(mihomo_service_cmd(self.scoop_dir), "mihomo 注册服务")

    def cmd_mihomo_toggle_service(self):
        action = "stop" if svc_state(MIHOMO_SVC) == "RUNNING" else "start"
        self.set_cmd("net {0} {1}".format(action, MIHOMO_SVC),
                     "mihomo {0}".format("停止服务" if action == "stop" else "启动服务"))

    def cmd_mihomo_delete_service(self):
        self.set_cmd("net stop {0}; sc.exe delete {0}".format(MIHOMO_SVC), "mihomo 删除服务")

    def open_dir(self, path: str):
        os.makedirs(path, exist_ok=True)
        if open_path(path):
            self.set_status("已打开：{0}".format(path))
        else:
            self.log_line("warn", "路径不存在：{0}".format(path))

    def open_mihomo_cfg(self):
        path = ensure_mihomo_cfg()
        if not path or not os.path.isfile(path):
            self.log_line("warn", "配置文件不存在且没有模板：security/placeholder_files/mihomo.yaml")
            return
        if open_path(path):
            self.set_status("已打开：{0}".format(path))

    def show_mihomo_openwrt(self):
        base = (self.ghproxy or "").strip().rstrip("/")
        gh_base = "https://github.com" if not base else base + "/https://github.com"
        text = OPENWRT_TPL.replace("@@VER@@", MIHOMO_CORE_VER).replace("@@GH_BASE@@", gh_base)

        dlg = tk.Toplevel(self)
        dlg.title("OpenWrt 安装命令")
        dlg.transient(self)
        dlg.geometry("900x520")
        body = ttk.Frame(dlg, padding=12)
        body.pack(fill="both", expand=True)
        ttk.Label(body, text="核心 v{0}    下载前缀 {1}".format(MIHOMO_CORE_VER, gh_base),
                  style="Muted.TLabel").pack(anchor="w")

        wrap = ttk.Frame(body)
        wrap.pack(fill="both", expand=True, pady=(8, 0))
        editor = tk.Text(wrap, wrap="none", font=FONT_MONO, bg=COLOR_PANEL, relief="flat",
                         highlightthickness=1, highlightbackground=COLOR_LINE, padx=8, pady=6)
        vsb = ttk.Scrollbar(wrap, orient="vertical", command=editor.yview)
        hsb = ttk.Scrollbar(wrap, orient="horizontal", command=editor.xview)
        editor.configure(yscrollcommand=vsb.set, xscrollcommand=hsb.set)
        editor.grid(row=0, column=0, sticky="nsew")
        vsb.grid(row=0, column=1, sticky="ns")
        hsb.grid(row=1, column=0, sticky="we")
        wrap.rowconfigure(0, weight=1)
        wrap.columnconfigure(0, weight=1)
        editor.insert("1.0", text)

        row = ttk.Frame(body)
        row.pack(fill="x", pady=(10, 0))
        ttk.Button(row, text="复制到剪贴板", style="Accent.TButton",
                   command=lambda: self.copy_text(editor.get("1.0", "end").strip())).pack(side="left")
        ttk.Button(row, text="关闭", command=dlg.destroy).pack(side="left", padx=6)

        dlg.grab_set()
        dlg.focus_set()

    def copy_text(self, text: str):
        self.clipboard_clear()
        self.clipboard_append(text)
        self.update_idletasks()
        self.set_status("已复制到剪贴板")

    def build_dotfiles_tab(self, parent):
        frame = ttk.Frame(parent, padding=12)
        parent.add(frame, text="dotfile 同步")

        head = ttk.Frame(frame)
        head.pack(fill="x")
        ttk.Label(head, text="备份 = 系统文件覆盖仓库文件；恢复 = 仓库文件覆盖系统文件",
                  style="Muted.TLabel").pack(side="left", pady=(4, 0))
        ttk.Button(head, text="刷新", command=self.refresh_dotfiles).pack(side="right")

        wrap = ttk.Frame(frame)
        wrap.pack(fill="both", expand=True, pady=(10, 0))
        self.dot_tree = ttk.Treeview(wrap, columns=("name", "target", "repo", "state"),
                                     show="headings", selectmode="browse")
        self.dot_tree.heading("name", text="名称")
        self.dot_tree.column("name", width=190, anchor="w")
        self.dot_tree.heading("target", text="系统文件")
        self.dot_tree.column("target", width=360, anchor="w")
        self.dot_tree.heading("repo", text="仓库文件（相对仓库根目录）")
        self.dot_tree.column("repo", width=300, anchor="w")
        self.dot_tree.heading("state", text="状态")
        self.dot_tree.column("state", width=200, anchor="w")
        scroll = ttk.Scrollbar(wrap, orient="vertical", command=self.dot_tree.yview)
        self.dot_tree.configure(yscrollcommand=scroll.set)
        self.dot_tree.pack(side="left", fill="both", expand=True)
        scroll.pack(side="right", fill="y")
        self.dot_tree.tag_configure("ok", foreground=COLOR_OK)
        self.dot_tree.tag_configure("bad", foreground="#a8071a")
        self.dot_tree.bind("<Double-1>", self.on_dot_double_click)
        self.dot_tree.bind("<<TreeviewSelect>>", lambda _e: self.set_status(
            "双击“系统文件”列打开配置所在目录，双击“仓库文件”列打开仓库文件位置"))

        row = ttk.Frame(frame)
        row.pack(fill="x", pady=(10, 0))
        ttk.Button(row, text="备份到仓库", style="Accent.TButton",
                   command=lambda: self.dot_action("backup")).pack(side="left")
        ttk.Button(row, text="从仓库恢复", command=lambda: self.dot_action("restore")).pack(
            side="left", padx=6)
        ttk.Button(row, text="全部备份", command=lambda: self.dot_action("backup_all")).pack(side="right")
        ttk.Button(row, text="全部恢复", command=lambda: self.dot_action("restore_all")).pack(
            side="right", padx=6)

    def build_search_tab(self, parent):
        frame = ttk.Frame(parent, padding=12)
        parent.add(frame, text="搜索")

        head = ttk.Frame(frame)
        head.pack(fill="x")
        ttk.Label(head, text="关键词", style="Value.TLabel").pack(side="left", padx=(0, 8))
        self.search_var = tk.StringVar()
        self.search_count_var = tk.StringVar()
        ttk.Entry(head, textvariable=self.search_var, font=FONT_UI).pack(
            side="left", fill="x", expand=True)
        ttk.Button(head, text="清空", command=lambda: self.search_var.set("")).pack(
            side="left", padx=(8, 0))
        ttk.Label(head, textvariable=self.search_count_var, style="Muted.TLabel").pack(
            side="left", padx=(10, 0))

        wrap = ttk.Frame(frame)
        wrap.pack(fill="both", expand=True, pady=(10, 0))
        self.search_tree = ttk.Treeview(wrap, columns=("kind", "path"), show="headings",
                                        selectmode="browse")
        self.search_tree.heading("kind", text="类别")
        self.search_tree.column("kind", width=140, anchor="w")
        self.search_tree.heading("path", text="位置")
        self.search_tree.column("path", width=720, anchor="w")
        scroll = ttk.Scrollbar(wrap, orient="vertical", command=self.search_tree.yview)
        self.search_tree.configure(yscrollcommand=scroll.set)
        self.search_tree.pack(side="left", fill="both", expand=True)
        scroll.pack(side="right", fill="y")

        self.search_rows = build_search_rows()
        self.search_var.trace_add("write", lambda *_args: self.run_search())

    def run_search(self):
        term = self.search_var.get().strip().lower()
        self.search_tree.delete(*self.search_tree.get_children())
        if not term:
            self.search_count_var.set("")
            return
        hits = [row for row in self.search_rows if term in row[2]]
        for kind, path, _keys in hits:
            self.search_tree.insert("", "end", values=(kind, path))
        self.search_count_var.set("匹配 {0} 项".format(len(hits)) if hits else "无匹配")

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
        group_title = list(SOFTWARE)[selection[0]]
        self.pkg_tree.delete(*self.pkg_tree.get_children())
        for pkg in SOFTWARE[group_title]:
            state = self.pkg_states.get(pkg.title, "未检测")
            tag = "missing" if "未安装" in state else "installed"
            self.pkg_tree.insert("", "end", iid=pkg.title,
                                 values=(pkg.title, pkg.kind(), state, pkg.desc), tags=(tag,))
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
            for pkgs in SOFTWARE.values():
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
        self.update_selection_actions()
        self.scoop_state_var.set("scoop: {0}".format("已安装" if scoop_installed(self.scoop_dir) else "未安装"))
        self.set_status("检测完成：{0}".format(time.strftime("%H:%M:%S")))

    def selected_pkg(self):
        selection = self.pkg_tree.selection()
        if not selection:
            return None
        return PKG_INDEX.get(selection[0])

    def on_pkg_select(self):
        self.current_pkg = self.selected_pkg()
        self.update_selection_actions()

    def toggle_altsnap_startup(self):
        if task_exists(ALTSNAP_TASK):
            if not messagebox.askyesno(APP_TITLE, "删除计划任务 {0}？".format(ALTSNAP_TASK)):
                return
            rc, out = run_elevated_script(altsnap_delete_script())
            if rc != 0:
                messagebox.showerror(APP_TITLE, "删除失败：{0}".format(out.strip() or "已取消或权限不足"))
            self.refresh_altsnap_button()
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
        self.refresh_altsnap_button()
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
        subprocess.Popen([exe, script], cwd=APP_DIR)
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
        rc, out = create_startup_shortcut(link, exe, script, APP_DIR)
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
        for title, item in DOTFILES.items():
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
            self.dot_tree.insert("", "end", iid=title,
                                 values=(title, item.target_display(), item.repo_display(), text), tags=(tag,))
        self.set_status("dotfile 状态已刷新")

    def selected_dot(self):
        selection = self.dot_tree.selection()
        if not selection:
            messagebox.showinfo(APP_TITLE, "请先在列表中选择一项")
            return None
        return DOTFILES.get(selection[0])

    def on_dot_double_click(self, event):
        row = self.dot_tree.identify_row(event.y)
        column = self.dot_tree.identify_column(event.x)
        if not row:
            return
        item = DOTFILES.get(row)
        if item is None:
            return
        if column in ("#1", "#2"):
            path = item.target_path()
            label = "配置目录"
        elif column == "#3":
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
            for item in DOTFILES.values():
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
