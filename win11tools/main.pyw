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
import winreg
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
RIME_WINGET_ID = "Rime.Weasel"
RIME_ICE_REPO = "iDvel/rime-ice"
RIME_PAGE_SIZE = 9
CTXMENU_KEY = r"HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
SPP_KEY = r"SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform"
KMS_HOST_DEFAULT = "192.168.1.1"
KMS_KEY_DEFAULT = "NRG8B-VKK3Q-CXVCJ-9G2XF-6Q84J"
TZ_KEY = r"HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation"
WU_POLICY = r"HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
WU_SERVICES = (("wuauserv", 3), ("UsoSvc", 2), ("WaaSMedicSvc", 3), ("uhssvc", 3))
WU_TASKS = (r"\Microsoft\Windows\InstallService*", r"\Microsoft\Windows\UpdateOrchestrator*",
            r"\Microsoft\Windows\UpdateAssistant*", r"\Microsoft\Windows\WaaSMedic*",
            r"\Microsoft\Windows\WindowsUpdate*", r"\Microsoft\WindowsUpdate*")
DEF_POLICY = r"HKLM\SOFTWARE\Policies\Microsoft\Windows Defender"
DEF_RT = DEF_POLICY + r"\Real-Time Protection"
DEF_SERVICES = (("WinDefend", 2), ("WdNisSvc", 3), ("Sense", 3))
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
COLOR_BAD = "#a8071a"

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


def first_file(paths) -> str:
    for path in paths:
        if path and os.path.isfile(path):
            return path
    return ""


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
        Package("Zellij", "Zellij.Zellij", "winget", ("Zellij.Zellij",)),
        Package("noctty", "AmanThanvi.noctty", "winget", ("AmanThanvi.noctty",)),
        Package("7-Zip", "7zip.7zip", "winget", ("7zip.7zip",)),
        Package("Git", "Git.Git", "winget", ("Git.Git",)),
        Package("lazygit", "JesseDuffield.lazygit", "winget", ("JesseDuffield.lazygit",)),
        Package(ALTSNAP_TITLE, "AltSnap.AltSnap", "winget", ("AltSnap.AltSnap",), panel="altsnap"),
        Package("Rime 小狼毫", "Rime.Weasel 中州韵输入法", "winget", (RIME_WINGET_ID,), panel="rime"),
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
    "系统配置": (
        Package("Win11 右键菜单", "Windows 11 默认菜单与传统菜单互相切换", "sysconfig", (),
                kind_label="系统配置", panel="ctxmenu"),
        Package("系统时间 UTC", "RTC 按 UTC 还是本地时间解释，支持强制对时", "sysconfig", (),
                kind_label="系统配置", panel="time"),
        Package("Windows Update", "禁用 / 恢复自动更新（tsgrgo/windows-update-disabler）", "sysconfig", (),
                kind_label="系统配置", panel="wupdate"),
        Package("Windows Defender", "禁用 / 恢复 Defender（ionuttbara/windows-defender-remover）", "sysconfig", (),
                kind_label="系统配置", panel="wdefender"),
        Package("激活管理", "KMS 激活：Key / KMS 地址可改，支持查看 Key、KMS 与激活状态", "sysconfig", (),
                kind_label="系统配置", panel="activation"),
        Package("onekey_startup.ahk", "启动、开机自启开关与编辑脚本", "sysconfig", (),
                kind_label="系统配置", panel="onekey"),
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

def all_packages():
    for pkgs in SOFTWARE.values():
        yield from pkgs


PKG_INDEX = {pkg.title: pkg for pkg in all_packages()}

DOTFILES = {
    "noctty config.ghostty": DotFile(r"%LOCALAPPDATA%\noctty\config.ghostty",
                                     r"win11.dotfiles\noctty_config.ghostty"),
    "nvim init.lua": DotFile(r"%LOCALAPPDATA%\nvim\init.lua",
                             r"win11.dotfiles\nvim_win_init.lua"),
    "helix config.toml": DotFile(r"%APPDATA%\helix\config.toml",
                                 r"..\dotfiles\helix_config.toml"),
    "zellij config.kdl": DotFile(r"%APPDATA%\Zellij\config.kdl",
                                 r"..\dotfiles\zellij_config.kdl"),
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
    "rime custom_phrase.txt": DotFile(r"%APPDATA%\Rime\custom_phrase.txt",
                                     r"win11.dotfiles\rime_custom_phrase.txt"),
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


def scoop_app_paths(scoop_dir: str, app: str, *parts):
    root = os.path.join(scoop_apps_dir(scoop_dir), app)
    paths = [os.path.join(root, "current", *parts)]
    if os.path.isdir(root):
        for name in sorted(os.listdir(root), reverse=True):
            if name != "current":
                paths.append(os.path.join(root, name, *parts))
    return paths


def winget_package_dirs(prefix: str):
    packages = os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "WinGet", "Packages")
    if not os.path.isdir(packages):
        return []
    return [os.path.join(packages, name) for name in sorted(os.listdir(packages), reverse=True)
            if name.lower().startswith(prefix)]


def set_user_env_cmd(name: str, value: str) -> str:
    return '[Environment]::SetEnvironmentVariable("{0}", "{1}", "User")'.format(name, value)


def user_path_cmd(path: str, add: bool) -> str:
    parts = [
        "$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')",
        "$paths = @($userPath -split ';' | Where-Object {{ $_ -and $_ -ne '{0}' }})".format(path),
    ]
    if add:
        parts.append("if ($paths -notcontains '{0}') {{ $paths += '{0}' }}".format(path))
    parts.append("[Environment]::SetEnvironmentVariable('Path', ($paths -join ';'), 'User')")
    return "; ".join(parts)


def remove_user_env_cmd(name: str) -> str:
    return '[Environment]::SetEnvironmentVariable("{0}", $null, "User")'.format(name)


def env_layout(pkg: Package):
    envs = {name: os.path.expandvars(value) for name, value in pkg.env}
    paths = [os.path.expandvars(path) for path in pkg.env_paths]
    return envs, paths


def env_apply_cmd(pkg: Package) -> str:
    envs, paths = env_layout(pkg)
    parts = [set_user_env_cmd(name, value) for name, value in envs.items()]
    parts.extend(user_path_cmd(path, True) for path in paths)
    parts.extend('$env:{0} = "{1}"'.format(name, value) for name, value in envs.items())
    if paths:
        joined = ";".join(paths)
        parts.append('$env:Path = "{0};" + $env:Path'.format(joined))
    return "; ".join(parts)


def env_cleanup_cmd(pkg: Package) -> str:
    envs, paths = env_layout(pkg)
    paths = paths + [os.path.expandvars(path) for path in pkg.env_cleanup_paths]
    parts = [user_path_cmd(path, False) for path in paths]
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
    if pkg.backend == "sysconfig":
        return ""
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
    if pkg.backend == "sysconfig":
        return ""
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


def remove_path_cmd(path: str) -> str:
    return 'Remove-Item "{0}" -Recurse -Force -ErrorAction SilentlyContinue'.format(path)


def mihomo_purge_cmd() -> str:
    parts = [
        "net stop {0}".format(MIHOMO_SVC),
        "sc.exe delete {0}".format(MIHOMO_SVC),
        "winget uninstall --id {0} -e".format(MIHOMO_WINGET_ID),
        remove_path_cmd(mihomo_home()),
        remove_path_cmd(mihomo_data_home()),
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


def reg_read(root, path: str, name: str):
    try:
        with winreg.OpenKey(root, path) as key:
            return winreg.QueryValueEx(key, name)[0]
    except OSError:
        return None


def service_start(service: str):
    return reg_read(winreg.HKEY_LOCAL_MACHINE,
                    "SYSTEM\\CurrentControlSet\\Services\\" + service, "Start")


def reg_add_cmd(key: str, name: str, value, kind: str = "REG_DWORD") -> str:
    return 'reg add "{0}" /v {1} /t {2} /d {3} /f'.format(key, name, kind, value)


def reg_del_cmd(key: str, name: str = "") -> str:
    return 'reg delete "{0}" /v {1} /f'.format(key, name) if name else 'reg delete "{0}" /f'.format(key)


def services_start_cmd(mapping) -> str:
    entries = "; ".join("'{0}'={1}".format(name, start) for name, start in mapping)
    return ("$svc = @{{{0}}}; foreach ($k in $svc.Keys) {{ "
            "$p = 'HKLM:\\SYSTEM\\CurrentControlSet\\Services\\' + $k; "
            "if (Test-Path $p) {{ New-ItemProperty -Path $p -Name Start "
            "-Value ([int]$svc[$k]) -PropertyType DWord -Force "
            "-ErrorAction SilentlyContinue | Out-Null }} }}").format(entries)


def stop_services_cmd(names) -> str:
    return "; ".join('Stop-Service -Name {0} -Force -ErrorAction SilentlyContinue'.format(name)
                    for name in names)


def ctxmenu_classic() -> bool:
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER,
                            r"Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"):
            return True
    except OSError:
        return False


def ctxmenu_state() -> str:
    return "传统菜单" if ctxmenu_classic() else "Windows 11 默认菜单"


def ctxmenu_cmd(classic: bool) -> str:
    key = CTXMENU_KEY.replace("HKCU\\", "HKCU:\\")
    if classic:
        body = "New-Item -Path '{0}\\InprocServer32' -Value '' -Force | Out-Null".format(key)
    else:
        body = "Remove-Item -Path '{0}' -Recurse -Force -ErrorAction SilentlyContinue".format(key)
    return body + "; Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue"


def time_utc() -> bool:
    return reg_read(winreg.HKEY_LOCAL_MACHINE,
                    r"SYSTEM\CurrentControlSet\Control\TimeZoneInformation", "RealTimeIsUniversal") == 1


def time_state() -> str:
    return "UTC（RTC 按 UTC 解释）" if time_utc() else "默认（RTC 按本地时间）"


def time_sync_cmd() -> str:
    return "Start-Service w32time -ErrorAction SilentlyContinue; w32tm /resync /force"


def time_cmd(utc: bool) -> str:
    if utc:
        return reg_add_cmd(TZ_KEY, "RealTimeIsUniversal", 1) + "; " + time_sync_cmd()
    return reg_del_cmd(TZ_KEY, "RealTimeIsUniversal")


def wu_tasks_cmd(action: str) -> str:
    paths = ", ".join("'" + path + "'" for path in WU_TASKS)
    verb = "Disable-ScheduledTask" if action == "disable" else "Enable-ScheduledTask"
    return ("$paths = @({0}); foreach ($p in $paths) {{ Get-ScheduledTask -TaskPath $p "
            "-ErrorAction SilentlyContinue | {1} -ErrorAction SilentlyContinue }}").format(paths, verb)


def wupdate_disabled() -> bool:
    if reg_read(winreg.HKEY_LOCAL_MACHINE,
                r"SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU", "NoAutoUpdate") == 1:
        return True
    return any(service_start(name) == 4 for name, _default in WU_SERVICES)


def wupdate_state() -> str:
    policy = reg_read(winreg.HKEY_LOCAL_MACHINE,
                      r"SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU", "NoAutoUpdate") == 1
    off = [name for name, _default in WU_SERVICES if service_start(name) == 4]
    if policy and len(off) == len(WU_SERVICES):
        return "已禁用（策略 + {0} 个服务）".format(len(off))
    if policy:
        return "策略已禁用（服务 {0}/{1}）".format(len(off), len(WU_SERVICES))
    if off:
        return "部分禁用（服务 {0}/{1}）".format(len(off), len(WU_SERVICES))
    return "默认（自动更新开启）"


def wupdate_cmd(disable: bool) -> str:
    names = [name for name, _default in WU_SERVICES]
    if disable:
        return "; ".join([
            services_start_cmd([(name, 4) for name in names]),
            reg_add_cmd(WU_POLICY, "NoAutoUpdate", 1),
            stop_services_cmd(names),
            wu_tasks_cmd("disable"),
        ])
    return "; ".join([
        services_start_cmd(WU_SERVICES),
        reg_del_cmd(WU_POLICY, "NoAutoUpdate"),
        wu_tasks_cmd("enable"),
        "Start-Service wuauserv -ErrorAction SilentlyContinue",
    ])


def defender_disabled() -> bool:
    if reg_read(winreg.HKEY_LOCAL_MACHINE,
                r"SOFTWARE\Policies\Microsoft\Windows Defender", "DisableAntiSpyware") == 1:
        return True
    return service_start("WinDefend") == 4


def defender_state() -> str:
    marks = []
    if reg_read(winreg.HKEY_LOCAL_MACHINE,
                r"SOFTWARE\Policies\Microsoft\Windows Defender", "DisableAntiSpyware") == 1:
        marks.append("策略 DisableAntiSpyware")
    if service_start("WinDefend") == 4:
        marks.append("WinDefend 服务禁用")
    return "已禁用（{0}）".format(" + ".join(marks)) if marks else "默认（Defender 启用）"


def defender_cmd(disable: bool) -> str:
    if disable:
        return "; ".join([
            reg_add_cmd(DEF_POLICY, "DisableAntiSpyware", 1),
            reg_add_cmd(DEF_POLICY, "DisableAntiVirus", 1),
            reg_add_cmd(DEF_POLICY, "ServiceKeepAlive", 0),
            reg_add_cmd(DEF_POLICY, "DisableLocalAdminMerge", 1),
            reg_add_cmd(DEF_RT, "DisableRealtimeMonitoring", 1),
            reg_add_cmd(DEF_RT, "DisableBehaviorMonitoring", 1),
            reg_add_cmd(DEF_RT, "DisableIOAVProtection", 1),
            reg_add_cmd(DEF_RT, "DisableOnAccessProtection", 1),
            reg_add_cmd(DEF_RT, "DisableScanOnRealtimeEnable", 1),
            services_start_cmd([(name, 4) for name, _default in DEF_SERVICES]),
            stop_services_cmd([name for name, _default in DEF_SERVICES]),
        ])
    return "; ".join([
        reg_del_cmd(DEF_POLICY, "DisableAntiSpyware"),
        reg_del_cmd(DEF_POLICY, "DisableAntiVirus"),
        reg_del_cmd(DEF_POLICY, "ServiceKeepAlive"),
        reg_del_cmd(DEF_POLICY, "DisableLocalAdminMerge"),
        reg_del_cmd(DEF_RT),
        services_start_cmd(DEF_SERVICES),
        "Start-Service WinDefend -ErrorAction SilentlyContinue",
    ])


def onekey_state() -> str:
    return "开机自启 已启用" if os.path.isfile(startup_shortcut()) else "开机自启 未启用"


def slmgr_path() -> str:
    return os.path.join(os.environ.get("SystemRoot", r"C:\Windows"), r"System32\slmgr.vbs")


def kms_host() -> str:
    value = reg_read(winreg.HKEY_LOCAL_MACHINE, SPP_KEY, "KeyManagementServiceName")
    return str(value).strip() if value else ""


def activation_state() -> str:
    host = kms_host()
    return "KMS {0}".format(host) if host else "KMS 未设置"


def slmgr_cmd(switch: str) -> str:
    return 'cscript //nologo "{0}" {1}'.format(slmgr_path(), switch)


def activation_cmd(key: str, host: str) -> str:
    steps = []
    if key.strip():
        steps.append(slmgr_cmd("/ipk " + key.strip()))
    if host.strip():
        steps.append(slmgr_cmd("/skms " + host.strip()))
    steps.append(slmgr_cmd("/ato"))
    return "; ".join(steps)


SYSCONFIG_STATE = {
    "ctxmenu": ctxmenu_state,
    "time": time_state,
    "wupdate": wupdate_state,
    "wdefender": defender_state,
    "activation": activation_state,
    "onekey": onekey_state,
}


def presence_state(label: str, present: int, total: int) -> str:
    if present == total:
        return label + " 已安装"
    if present:
        return "{0} 部分安装 {1}/{2}".format(label, present, total)
    return "未安装"


def pkg_state(pkg: Package, winget_text: str, scoop_dir: str, scoop_apps=None) -> str:
    if pkg.backend == "sysconfig":
        return SYSCONFIG_STATE[pkg.panel]()
    if scoop_apps is None:
        scoop_apps = scoop_app_names(scoop_dir)
    if pkg.special == "scoop_self":
        return "scoop 已安装" if scoop_installed(scoop_dir) else "未安装"
    if pkg.backend == "winget":
        low = winget_text.lower()
        present = sum(1 for n in pkg.names if n.lower() in low)
        if not present:
            probes = [pkg.scoop_alias] if pkg.scoop_alias else [n.split(".")[-1] for n in pkg.names]
            if any(norm_name(probe) in scoop_apps for probe in probes):
                return "scoop 已安装"
        return presence_state("winget", present, len(pkg.names))
    present = sum(1 for n in pkg.names if norm_name(n) in scoop_apps)
    return presence_state("scoop", present, len(pkg.names))


def winget_list_text() -> str:
    rc, out = run_capture(["winget", "list", "--accept-source-agreements"], timeout=180)
    if rc != 0 and not out.strip():
        return ""
    return out


def find_altsnap_exe(scoop_dir: str) -> str:
    cands = scoop_app_paths(scoop_dir, "altsnap", "AltSnap.exe")
    for var in ("APPDATA", "LOCALAPPDATA", "ProgramFiles", "ProgramFiles(x86)"):
        base = os.environ.get(var)
        if not base:
            continue
        cands.append(os.path.join(base, "AltSnap", "AltSnap.exe"))
        cands.append(os.path.join(base, "Programs", "AltSnap", "AltSnap.exe"))
    task_command = scheduled_task_command(ALTSNAP_TASK)
    if task_command:
        cands.append(task_command)
    return first_file(cands) or shutil.which("AltSnap.exe") or shutil.which("altsnap.exe") or ""


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
    roots = [scoop_dir, os.environ.get("SCOOP", ""), default_scoop_dir()]
    cands = []
    for root in dict.fromkeys(root for root in roots if root):
        cands.extend(scoop_app_paths(root, "autohotkey", "v2", "AutoHotkey64.exe"))
    for var in ("ProgramFiles", "ProgramFiles(x86)", "LOCALAPPDATA"):
        base = os.environ.get(var)
        if base:
            cands.append(os.path.join(base, "AutoHotkey", "v2", "AutoHotkey64.exe"))
            cands.append(os.path.join(base, "Programs", "AutoHotkey", "v2", "AutoHotkey64.exe"))
    return first_file(cands)


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
    for folder in winget_package_dirs("metacubex.mihomo"):
        cands.append(os.path.join(folder, "mihomo.exe"))
        for root, _dirs, files in os.walk(folder):
            if "mihomo.exe" in [f.lower() for f in files]:
                cands.append(os.path.join(root, "mihomo.exe"))
                break
    return first_file(cands) or shutil.which("mihomo.exe") or shutil.which("mihomo") or ""


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
    return first_file([os.path.join(mihomo_home(), "nssm.exe")]
                      + scoop_app_paths(scoop_dir, "nssm", "win64", "nssm.exe"))


def write_text(path: str, text: str):
    folder = os.path.dirname(path)
    if folder:
        os.makedirs(folder, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write(text)


def copy_tree(src: str, dst: str, skip=()) -> int:
    os.makedirs(dst, exist_ok=True)
    count = 0
    for name in os.listdir(src):
        if name in skip:
            continue
        source = os.path.join(src, name)
        target = os.path.join(dst, name)
        if os.path.isdir(source):
            shutil.copytree(source, target, dirs_exist_ok=True)
        else:
            shutil.copy2(source, target)
        count += 1
    return count


def rime_user_dir() -> str:
    return os.path.join(os.environ.get("APPDATA", ""), "Rime")


def find_weasel_deployer() -> str:
    for var in ("ProgramFiles", "ProgramFiles(x86)"):
        root = os.path.join(os.environ.get(var, ""), "Rime")
        if not os.path.isdir(root):
            continue
        for current, _dirs, files in os.walk(root):
            if "weaseldeployer.exe" in [name.lower() for name in files]:
                return os.path.join(current, "WeaselDeployer.exe")
    return ""


def ensure_rime_ice_schema() -> str:
    path = os.path.join(rime_user_dir(), "default.custom.yaml")
    schema_line = "    - {schema: rime_ice}"
    if not os.path.isfile(path):
        write_text(path, "patch:\n  schema_list:\n" + schema_line + "\n")
        return "已写入 default.custom.yaml"
    with open(path, encoding="utf-8-sig") as fh:
        lines = fh.read().splitlines()
    if "rime_ice" in "\n".join(lines):
        return "default.custom.yaml 已包含 rime_ice"
    for idx, line in enumerate(lines):
        if line.strip() == "schema_list:":
            indent = line[:len(line) - len(line.lstrip())] + "  "
            lines.insert(idx + 1, indent + "- {schema: rime_ice}")
            break
    else:
        if "patch:" not in [line.strip() for line in lines]:
            lines.append("patch:")
        lines.extend(["  schema_list:", schema_line])
    write_text(path, "\n".join(lines) + "\n")
    return "已把 rime_ice 加入 schema_list"


def rime_line_key(line: str) -> str:
    return line.split(":", 1)[0].strip().strip("\"'") if ":" in line else ""


def ensure_rime_page_size(size: int = RIME_PAGE_SIZE) -> str:
    path = os.path.join(rime_user_dir(), "default.custom.yaml")
    key = "menu/page_size"
    line = "  {0}: {1}".format(key, size)
    if not os.path.isfile(path):
        write_text(path, "patch:\n" + line + "\n")
        return "已写入 default.custom.yaml（{0}: {1}）".format(key, size)
    with open(path, encoding="utf-8-sig") as fh:
        lines = fh.read().splitlines()
    hits = [idx for idx, text in enumerate(lines) if rime_line_key(text) == key]
    if hits:
        value = lines[hits[0]].split(":", 1)[1].strip().strip("\"'")
        if value == str(size) and len(hits) == 1:
            return "{0} 已是 {1}".format(key, size)
        lines[hits[0]] = line
        for idx in reversed(hits[1:]):
            del lines[idx]
    else:
        for idx, text in enumerate(lines):
            if text.strip() == "patch:":
                lines.insert(idx + 1, line)
                break
        else:
            lines.extend(["patch:", line])
    write_text(path, "\n".join(lines) + "\n")
    return "已设置 {0}: {1}".format(key, size)


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


def try_github_urls(proxy: str, path: str, action, what: str, log=None):
    problems = []
    urls = github_urls(proxy, path)
    for idx, url in enumerate(urls):
        try:
            return action(url)
        except Exception as exc:
            problems.append("{0} -> {1}".format(url, exc))
            if log and idx + 1 < len(urls):
                log("warn", "{0}失败（{1}），改用直连 GitHub 重试".format(what, exc))
    raise RuntimeError("{0}失败: {1}".format(what, "；".join(problems)))


def download_github_zip(proxy: str, path: str, member: str, extract_to: str, progress=None, log=None):
    return try_github_urls(proxy, path,
                           lambda url: download_zip_member(url, member, extract_to, progress),
                           "下载", log)


def get_github_json(proxy: str, path: str, log=None):
    import json as json_mod
    import urllib.request

    def fetch(url):
        req = urllib.request.Request(url, headers={"User-Agent": "win11tools"})
        with urllib.request.urlopen(req, timeout=60) as resp:
            return json_mod.loads(resp.read().decode("utf-8"))

    return try_github_urls(proxy, path, fetch, "查询", log)


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


def make_tree(parent, columns, pady=(0, 0)):
    wrap = ttk.Frame(parent)
    wrap.pack(fill="both", expand=True, pady=pady)
    tree = ttk.Treeview(wrap, columns=[col[0] for col in columns], show="headings",
                        selectmode="browse")
    for key, heading, width in columns:
        tree.heading(key, text=heading)
        tree.column(key, width=width, anchor="w")
    scroll = ttk.Scrollbar(wrap, orient="vertical", command=tree.yview)
    tree.configure(yscrollcommand=scroll.set)
    tree.pack(side="left", fill="both", expand=True)
    scroll.pack(side="right", fill="y")
    return tree


def scrolled_text(parent, height=6, horizontal=False):
    wrap = ttk.Frame(parent)
    wrap.pack(fill="both", expand=True, pady=(8, 0))
    text = tk.Text(wrap, width=1, height=height, wrap="none", font=FONT_MONO,
                   bg=COLOR_PANEL, relief="flat", highlightthickness=1,
                   highlightbackground=COLOR_LINE, padx=8, pady=6)
    vsb = ttk.Scrollbar(wrap, orient="vertical", command=text.yview)
    text.configure(yscrollcommand=vsb.set)
    text.grid(row=0, column=0, sticky="nsew")
    vsb.grid(row=0, column=1, sticky="ns")
    if horizontal:
        hsb = ttk.Scrollbar(wrap, orient="horizontal", command=text.xview)
        text.configure(xscrollcommand=hsb.set)
        hsb.grid(row=1, column=0, sticky="we")
    wrap.rowconfigure(0, weight=1)
    wrap.columnconfigure(0, weight=1)
    return text


def grid_buttons(parent, specs, columns=4):
    for idx, (label, command, accent) in enumerate(specs):
        ttk.Button(parent, text=label, command=command,
                   style="Accent.TButton" if accent else "TButton").grid(
            row=idx // columns, column=idx % columns, sticky="we", padx=3, pady=3)
    for col in range(columns):
        parent.columnconfigure(col, weight=1)


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
        self.startup_toggle_btn = None
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
        self.build_dotfiles_tab(self.notebook)

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
        ttk.Label(head, text="软件安装 · 系统配置 · dotfile 同步", style="Muted.TLabel").pack(
            side="left", padx=(12, 0), pady=(8, 0))
        ttk.Button(head, text="首选项", command=self.open_preferences).pack(side="right")
        ttk.Button(head, text="搜索", command=self.open_search).pack(side="right", padx=(0, 6))

    def build_log_panel(self, parent):
        frame = ttk.LabelFrame(parent, text="日志", padding=(10, 8))
        frame.pack(fill="x", padx=12, pady=(8, 12))

        head = ttk.Frame(frame)
        head.pack(fill="x")
        ttk.Button(head, text="复制日志", command=self.copy_log).pack(side="right")
        ttk.Button(head, text="清空", command=self.clear_log).pack(side="right", padx=(0, 6))

        self.log_text = scrolled_text(frame, 6)
        for level, color in (("info", COLOR_FG), ("ok", COLOR_OK),
                             ("warn", COLOR_WARN), ("error", COLOR_ERR)):
            self.log_text.tag_config(level, foreground=color)
        self.log_text.configure(state="disabled")

    def copy_to_clipboard(self, text: str, status: str = "已复制到剪贴板") -> bool:
        if not text:
            return False
        self.clipboard_clear()
        self.clipboard_append(text)
        self.update_idletasks()
        self.set_status(status)
        return True

    def copy_log(self):
        if not self.copy_to_clipboard(self.log_text.get("1.0", "end").strip(), "日志已复制到剪贴板"):
            self.set_status("日志为空")

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
        self.pkg_tree = make_tree(right, (
            ("name", "名称", 200),
            ("kind", "类型", 90),
            ("state", "状态", 150),
            ("desc", "说明", 420),
        ))
        self.pkg_tree.bind("<<TreeviewSelect>>", lambda _e: self.on_pkg_select())
        self.pkg_tree.bind("<Double-1>", lambda _e: self.fill_cmd("install"))
        self.pkg_tree.tag_configure("installed", foreground=COLOR_OK)
        self.pkg_tree.tag_configure("missing", foreground=COLOR_BAD)

        cmd_box = ttk.LabelFrame(frame, text="命令（可编辑后复制或运行）", padding=10)
        cmd_box.pack(fill="x", pady=(12, 0))
        self.cmd_box = cmd_box
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

        self.extra_frame = ttk.Frame(frame)

        self.group_list.selection_set(0)
        self.show_group()

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

    def has_cmd(self, pkg: Package) -> bool:
        return bool(build_install_cmd(pkg, self.scoop_dir) or build_uninstall_cmd(pkg, self.scoop_dir))

    def toggle_cmd_box(self, visible: bool):
        packed = bool(self.cmd_box.winfo_manager())
        if visible and not packed:
            if self.extra_frame.winfo_manager():
                self.cmd_box.pack(fill="x", pady=(12, 0), before=self.extra_frame)
            else:
                self.cmd_box.pack(fill="x", pady=(12, 0))
        elif not visible and packed:
            self.cmd_box.pack_forget()

    def update_selection_actions(self):
        for child in self.extra_frame.winfo_children():
            child.destroy()
        pkg = self.current_pkg
        self.toggle_cmd_box(pkg is None or self.has_cmd(pkg))
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
        builder = {
            "altsnap": self.build_altsnap_actions,
            "mihomo": self.build_mihomo_actions,
            "rime": self.build_rime_actions,
            "ctxmenu": self.build_ctxmenu_actions,
            "time": self.build_time_actions,
            "wupdate": self.build_wupdate_actions,
            "wdefender": self.build_wdefender_actions,
            "activation": self.build_activation_actions,
            "onekey": self.build_onekey_actions,
        }.get(pkg.panel)
        if builder is None:
            self.extra_frame.pack_forget()
            return
        self.extra_frame.pack(fill="x", pady=(10, 0))
        builder()

    def build_action_panel(self, status: str, *buttons):
        ttk.Label(self.extra_frame, text=status, style="Muted.TLabel").pack(anchor="w")
        row = ttk.Frame(self.extra_frame)
        row.pack(fill="x", pady=(6, 0))
        for label, command, accent in buttons:
            ttk.Button(row, text=label, command=command,
                       style="Accent.TButton" if accent else "TButton").pack(side="left", padx=(0, 6))

    def run_local(self, command: str, label: str) -> bool:
        if not command:
            return False
        self.cmd_var.set(command)
        rc, out = run_capture([find_powershell(), "-NoProfile", "-NonInteractive", "-Command", command],
                              timeout=60)
        if rc != 0:
            self.log_line("error", "{0}失败：{1}".format(label, out.strip() or "rc={0}".format(rc)))
            self.set_status("{0}失败".format(label))
            return False
        self.log_line("ok", label)
        self.set_status(label)
        return True

    def run_admin(self, command: str, label: str) -> bool:
        if not command:
            return False
        if not messagebox.askyesno(APP_TITLE, "{0}？\n\n会弹出 UAC，以管理员权限执行。".format(label)):
            return False
        self.cmd_var.set(command)
        self.log_line("info", "执行（管理员）：{0}".format(label))
        rc, out = run_elevated_script(command)
        if rc != 0:
            self.log_line("error", "{0}失败：{1}".format(label, out.strip() or "已取消或权限不足"))
            self.set_status("{0}失败".format(label))
            return False
        self.log_line("ok", label)
        self.set_status(label)
        return True

    def build_ctxmenu_actions(self):
        classic = ctxmenu_classic()
        self.build_action_panel(
            "右键菜单：{0}".format(ctxmenu_state()),
            ("切换为传统菜单" if not classic else "恢复 Windows 11 默认菜单",
             lambda: self.apply_ctxmenu(not classic), True),
        )

    def refresh_sysconfig_state(self, title: str):
        pkg = PKG_INDEX.get(title)
        if pkg is None or pkg.backend != "sysconfig":
            return
        state = pkg_state(pkg, self.winget_text, self.scoop_dir)
        self.pkg_states[title] = state
        if self.pkg_tree.exists(title):
            self.pkg_tree.set(title, "state", state)
        self.log_line("info", "{0} 现在：{1}".format(title, state))

    def apply_ctxmenu(self, classic: bool):
        label = "切换为传统菜单" if classic else "恢复 Windows 11 默认菜单"
        if self.run_local(ctxmenu_cmd(classic), label):
            self.refresh_sysconfig_state("Win11 右键菜单")
            self.update_selection_actions()

    def build_time_actions(self):
        utc = time_utc()
        self.build_action_panel(
            "系统时间：{0}".format(time_state()),
            ("改用 UTC（RTC=UTC）" if not utc else "恢复默认（RTC=本地时间）",
             lambda: self.apply_time(not utc), True),
            ("强制对时一次", self.resync_time, False),
        )

    def apply_time(self, utc: bool):
        label = "切换为 UTC 时间" if utc else "恢复默认时间"
        if self.run_admin(time_cmd(utc), label):
            self.refresh_sysconfig_state("系统时间 UTC")
            self.update_selection_actions()

    def resync_time(self):
        self.run_admin(time_sync_cmd(), "强制对时")

    def build_wupdate_actions(self):
        disabled = wupdate_disabled()
        self.build_action_panel(
            "Windows Update：{0}".format(wupdate_state()),
            ("禁用 Windows Update" if not disabled else "恢复 Windows Update",
             lambda: self.apply_wupdate(not disabled), True),
        )

    def apply_wupdate(self, disable: bool):
        label = "禁用 Windows Update" if disable else "恢复 Windows Update"
        if self.run_admin(wupdate_cmd(disable), label):
            self.refresh_sysconfig_state("Windows Update")
            self.update_selection_actions()

    def build_wdefender_actions(self):
        disabled = defender_disabled()
        self.build_action_panel(
            "Windows Defender：{0}".format(defender_state()),
            ("禁用 Windows Defender" if not disabled else "恢复 Windows Defender",
             lambda: self.apply_wdefender(not disabled), True),
        )

    def apply_wdefender(self, disable: bool):
        label = "禁用 Windows Defender" if disable else "恢复 Windows Defender"
        if self.run_admin(defender_cmd(disable), label):
            self.refresh_sysconfig_state("Windows Defender")
            self.update_selection_actions()

    def build_activation_actions(self):
        host = kms_host()
        ttk.Label(self.extra_frame,
                  text="激活：{0}".format("KMS " + host if host else "KMS 未设置"),
                  style="Muted.TLabel").pack(anchor="w")
        form = ttk.Frame(self.extra_frame)
        form.pack(fill="x", pady=(6, 0))
        self.kms_host_var = tk.StringVar(value=host or KMS_HOST_DEFAULT)
        self.kms_key_var = tk.StringVar(value=KMS_KEY_DEFAULT)
        ttk.Label(form, text="KMS 地址").grid(row=0, column=0, sticky="w", padx=(0, 6), pady=2)
        ttk.Entry(form, textvariable=self.kms_host_var, width=20, font=FONT_MONO).grid(
            row=0, column=1, sticky="w", pady=2)
        ttk.Label(form, text="Key（GVLK）").grid(row=1, column=0, sticky="w", padx=(0, 6), pady=2)
        ttk.Entry(form, textvariable=self.kms_key_var, width=34, font=FONT_MONO).grid(
            row=1, column=1, sticky="w", pady=2)
        row = ttk.Frame(self.extra_frame)
        row.pack(fill="x", pady=(8, 0))
        grid_buttons(row, (
            ("应用并激活", self.apply_activation, True),
            ("查看激活状态", lambda: self.show_slmgr_report("/xpr", "Windows 激活状态"), False),
            ("查看 Key / KMS", lambda: self.show_slmgr_report("/dlv", "已安装的 Key 与 KMS"), False),
        ), columns=3)

    def apply_activation(self):
        key = self.kms_key_var.get().strip().upper()
        host = self.kms_host_var.get().strip()
        if not key and not host:
            self.set_status("请填写 Key 或 KMS 地址")
            return
        if key and not re.match(r"^[A-Z0-9]{5}(-[A-Z0-9]{5}){4}$", key):
            self.set_status("Key 格式不对：需要 5 组、每组 5 位字母或数字")
            return
        if self.run_admin(activation_cmd(key, host), "应用并激活"):
            self.refresh_sysconfig_state("激活管理")
            self.show_slmgr_report("/dli", "激活结果")

    def show_slmgr_report(self, switch: str, title: str):
        rc, out = run_capture(["cscript", "//nologo", slmgr_path(), switch], timeout=90)
        text = out.strip() or "无输出（rc={0}）".format(rc)

        dlg = tk.Toplevel(self)
        dlg.title(title)
        dlg.transient(self)
        dlg.geometry("720x460")
        body = ttk.Frame(dlg, padding=12)
        body.pack(fill="both", expand=True)
        ttk.Label(body, text="slmgr.vbs {0}".format(switch), style="Muted.TLabel").pack(anchor="w")

        editor = scrolled_text(body, 18, horizontal=True)
        editor.insert("1.0", text)

        row = ttk.Frame(body)
        row.pack(fill="x", pady=(10, 0))
        ttk.Button(row, text="复制到剪贴板", style="Accent.TButton",
                   command=lambda: self.copy_to_clipboard(editor.get("1.0", "end").strip())).pack(side="left")
        ttk.Button(row, text="关闭", command=dlg.destroy).pack(side="left", padx=6)

        dlg.grab_set()
        dlg.focus_set()
        self.set_status("{0}：{1}".format(title, "已获取" if out.strip() else "无输出"))

    def build_onekey_actions(self):
        enabled = os.path.isfile(startup_shortcut())
        ttk.Label(self.extra_frame, text="onekey_startup.ahk：{0}".format(onekey_state()),
                  style="Muted.TLabel").pack(anchor="w")
        row = ttk.Frame(self.extra_frame)
        row.pack(fill="x", pady=(6, 0))
        ttk.Button(row, text="启动", style="Accent.TButton",
                   command=self.feature_start_onekey).pack(side="left")
        self.startup_toggle_btn = ttk.Button(
            row, text="禁止自动启动" if enabled else "允许自动启动",
            command=self.feature_toggle_startup)
        self.startup_toggle_btn.pack(side="left", padx=6)
        ttk.Button(row, text="编辑脚本",
                   command=self.feature_edit_onekey).pack(side="left")

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
        grid_buttons(buttons, (
            ("安装 / 更新面板", self.cmd_mihomo_panel, True),
            ("注册服务", self.cmd_mihomo_service, False),
            ("停止服务" if running else "启动服务", self.cmd_mihomo_toggle_service, False),
            ("删除服务", self.cmd_mihomo_delete_service, False),
            ("打开配置", self.open_mihomo_cfg, False),
            ("打开数据目录", lambda: self.open_dir(mihomo_data_home()), False),
            ("打开安装目录", lambda: self.open_dir(mihomo_home()), False),
            ("OpenWrt 命令", self.show_mihomo_openwrt, False),
        ))

    def rime_status_text(self) -> str:
        exe = find_weasel_deployer()
        return "Weasel: {0}    用户目录: {1}".format(
            os.path.dirname(exe) if exe else "未找到 WeaselDeployer.exe", rime_user_dir())

    def build_rime_actions(self):
        ttk.Label(self.extra_frame, text=self.rime_status_text(), style="Muted.TLabel").pack(anchor="w")
        buttons = ttk.Frame(self.extra_frame)
        buttons.pack(fill="x", pady=(6, 0))
        grid_buttons(buttons, (
            ("安装 / 更新 ice 词库", self.install_rime_ice, True),
            ("候选字→{0}".format(RIME_PAGE_SIZE), self.apply_rime_page_size, False),
            ("部署", self.deploy_rime, False),
            ("打开用户目录", lambda: self.open_dir(rime_user_dir()), False),
        ), columns=4)

    def apply_rime_page_size(self):
        try:
            note = ensure_rime_page_size()
        except OSError as exc:
            messagebox.showerror(APP_TITLE, "写入失败：{0}".format(exc))
            return
        self.log_line("ok", "Rime 候选数：{0}".format(note))
        self.deploy_rime()

    def deploy_rime(self):
        exe = find_weasel_deployer()
        if not exe:
            messagebox.showwarning(APP_TITLE, "未找到 WeaselDeployer.exe，请先安装 Rime 小狼毫")
            return
        subprocess.Popen([exe, "/deploy"], cwd=os.path.dirname(exe))
        self.log_line("info", "Rime 部署：{0}".format(exe))
        self.set_status("已提交 Rime 部署")

    def install_rime_ice(self):
        if not messagebox.askyesno(APP_TITLE, "下载 rime-ice 到：\n{0}\n\n不会覆盖 custom_phrase.txt".format(
                rime_user_dir())):
            return
        self.log_line("info", "开始下载 rime-ice ...")
        self.set_status("正在下载 ice 词库 ...")

        def work():
            temp = os.path.join(tempfile.gettempdir(), "rime-ice-download")
            member = download_github_zip(self.ghproxy,
                                         RIME_ICE_REPO + "/archive/refs/heads/main.zip",
                                         "rime_ice.schema.yaml", temp)
            copied = copy_tree(os.path.dirname(member), rime_user_dir(), skip=("custom_phrase.txt",))
            note = ensure_rime_ice_schema()
            exe = find_weasel_deployer()
            if exe:
                subprocess.Popen([exe, "/deploy"], cwd=os.path.dirname(exe))
            return copied, note, exe

        def done(result):
            if isinstance(result, Exception):
                self.log_line("error", "ice 词库安装失败：{0}".format(result))
                self.set_status("ice 词库安装失败")
                return
            copied, note, exe = result
            self.log_line("ok", "ice 词库已更新：{0} 项，{1}".format(copied, note))
            self.log_line("info", "Rime 部署：{0}".format(exe or "未找到 WeaselDeployer.exe，请手动部署"))
            self.set_status("ice 词库安装完成")
            self.update_selection_actions()

        self.run_async(work, done)

    def run_async(self, work, done):
        def runner():
            try:
                result = work()
            except Exception as exc:
                result = exc
            self.after(0, lambda: done(result))

        threading.Thread(target=runner, daemon=True).start()

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

    def open_report(self, path: str, label: str = "", alert: bool = False, containing: bool = False) -> bool:
        opener = open_containing if containing else open_path
        if not opener(path):
            if alert:
                messagebox.showinfo(APP_TITLE, "路径不存在：{0}".format(path))
            else:
                self.log_line("warn", "路径不存在：{0}".format(path))
            return False
        self.set_status("已打开{0}：{1}".format(label, path) if label else "已打开：{0}".format(path))
        return True

    def open_dir(self, path: str):
        os.makedirs(path, exist_ok=True)
        self.open_report(path)

    def open_mihomo_cfg(self):
        path = ensure_mihomo_cfg()
        if not path or not os.path.isfile(path):
            self.log_line("warn", "配置文件不存在且没有模板：security/placeholder_files/mihomo.yaml")
            return
        self.open_report(path)

    def show_mihomo_openwrt(self):
        gh_base = gh_url(self.ghproxy, "https://github.com")
        text = OPENWRT_TPL.replace("@@VER@@", MIHOMO_CORE_VER).replace("@@GH_BASE@@", gh_base)

        dlg = tk.Toplevel(self)
        dlg.title("OpenWrt 安装命令")
        dlg.transient(self)
        dlg.geometry("900x520")
        body = ttk.Frame(dlg, padding=12)
        body.pack(fill="both", expand=True)
        ttk.Label(body, text="核心 v{0}    下载前缀 {1}".format(MIHOMO_CORE_VER, gh_base),
                  style="Muted.TLabel").pack(anchor="w")

        editor = scrolled_text(body, 20, horizontal=True)
        editor.insert("1.0", text)

        row = ttk.Frame(body)
        row.pack(fill="x", pady=(10, 0))
        ttk.Button(row, text="复制到剪贴板", style="Accent.TButton",
                   command=lambda: self.copy_to_clipboard(editor.get("1.0", "end").strip())).pack(side="left")
        ttk.Button(row, text="关闭", command=dlg.destroy).pack(side="left", padx=6)

        dlg.grab_set()
        dlg.focus_set()

    def build_dotfiles_tab(self, parent):
        frame = ttk.Frame(parent, padding=12)
        parent.add(frame, text="dotfile 同步")

        head = ttk.Frame(frame)
        head.pack(fill="x")
        ttk.Label(head, text="备份 = 系统文件覆盖仓库文件；恢复 = 仓库文件覆盖系统文件",
                  style="Muted.TLabel").pack(side="left", pady=(4, 0))
        ttk.Button(head, text="刷新", command=self.refresh_dotfiles).pack(side="right")

        self.dot_tree = make_tree(frame, (
            ("name", "名称", 190),
            ("target", "系统文件", 360),
            ("repo", "仓库文件（相对仓库根目录）", 300),
            ("state", "状态", 200),
        ), pady=(10, 0))
        self.dot_tree.tag_configure("ok", foreground=COLOR_OK)
        self.dot_tree.tag_configure("bad", foreground=COLOR_BAD)
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

    def open_search(self):
        dlg = tk.Toplevel(self)
        dlg.title("搜索")
        dlg.transient(self)
        dlg.geometry("760x520")
        body = ttk.Frame(dlg, padding=12)
        body.pack(fill="both", expand=True)

        head = ttk.Frame(body)
        head.pack(fill="x")
        term_var = tk.StringVar()
        count_var = tk.StringVar()
        entry = ttk.Entry(head, textvariable=term_var, font=FONT_UI)
        entry.pack(side="left", fill="x", expand=True)
        ttk.Button(head, text="清空", command=lambda: term_var.set("")).pack(side="left", padx=(8, 0))
        ttk.Label(head, textvariable=count_var, style="Muted.TLabel").pack(side="left", padx=(10, 0))

        tree = make_tree(body, (
            ("kind", "类别", 140),
            ("path", "位置", 620),
        ), pady=(10, 0))
        rows = build_search_rows()

        def run(*_args):
            term = term_var.get().strip().lower()
            tree.delete(*tree.get_children())
            if not term:
                count_var.set("")
                return
            hits = [row for row in rows if term in row[2]]
            for kind, path, _keys in hits:
                tree.insert("", "end", values=(kind, path))
            count_var.set("匹配 {0} 项".format(len(hits)) if hits else "无匹配")

        term_var.trace_add("write", run)
        dlg.bind("<Escape>", lambda _e: dlg.destroy())
        entry.focus_set()

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
        self.update_selection_actions()

    def refresh_packages(self):
        scoop_dir = self.scoop_dir
        self.set_status("正在检测已安装软件 ...")
        self.scoop_state_var.set(self.scoop_state_text())

        self.pkg_gen += 1
        gen = self.pkg_gen

        def work():
            text = winget_list_text()
            apps = scoop_app_names(scoop_dir)
            states = {pkg.title: pkg_state(pkg, text, scoop_dir, apps) for pkg in all_packages()}
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
        self.scoop_state_var.set(self.scoop_state_text())
        self.set_status("检测完成：{0}".format(time.strftime("%H:%M:%S")))

    def scoop_state_text(self) -> str:
        return "scoop: {0}".format("已安装" if scoop_installed(self.scoop_dir) else "未安装")

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
            self.run_task_script(altsnap_delete_script(), "删除失败")
            state = "已删除" if not task_exists(ALTSNAP_TASK) else "仍存在"
        else:
            exe = find_altsnap_exe(self.scoop_dir)
            if not exe:
                messagebox.showwarning(APP_TITLE, "未找到 AltSnap.exe，请先安装 AltSnap")
                return
            if not messagebox.askyesno(APP_TITLE, "以管理员权限在登录时启动？\n{0}".format(exe)):
                return
            self.run_task_script(altsnap_startup_script(exe), "创建失败")
            state = "已创建" if task_exists(ALTSNAP_TASK) else "未创建"
        self.refresh_altsnap_button()
        self.set_status("计划任务 {0}：{1}".format(ALTSNAP_TASK, state))

    def run_task_script(self, script: str, failure: str) -> bool:
        rc, out = run_elevated_script(script)
        if rc != 0:
            messagebox.showerror(APP_TITLE, "{0}：{1}".format(failure, out.strip() or "已取消或权限不足"))
            return False
        return True

    def fill_cmd(self, action: str):
        pkg = self.current_pkg or self.selected_pkg()
        if pkg is None:
            self.set_status("请先在列表中选择一个软件")
            return
        command = (build_install_cmd(pkg, self.scoop_dir) if action == "install"
                   else build_uninstall_cmd(pkg, self.scoop_dir))
        if not command:
            self.set_status("{0} 没有安装/卸载命令，请用下方操作按钮".format(pkg.title))
            return
        self.cmd_var.set(command)
        self.set_status("{0}：{1}".format("安装命令" if action == "install" else "卸载命令", pkg.title))

    def copy_cmd(self):
        if not self.copy_to_clipboard(self.cmd_var.get().strip(), "命令已复制到剪贴板"):
            self.set_status("没有可复制的命令")

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
        self.update_selection_actions()

    def require_onekey(self):
        script = onekey_script()
        if not os.path.isfile(script):
            messagebox.showerror(APP_TITLE, "找不到脚本：{0}".format(script))
            return None, ""
        exe = find_ahk_exe(self.scoop_dir)
        if not exe:
            messagebox.showerror(APP_TITLE, "未找到 AutoHotkey64.exe，请先安装 AutoHotkey")
            return None, ""
        return script, exe

    def feature_start_onekey(self):
        script, exe = self.require_onekey()
        if not script:
            return
        subprocess.Popen([exe, script], cwd=APP_DIR)
        self.set_status("已启动 onekey_startup.ahk")

    def feature_add_startup(self):
        script, exe = self.require_onekey()
        if not script:
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
            has_target = os.path.isfile(target)
            has_repo = os.path.isfile(repo)
            text = "{0} / {1}".format("系统有" if has_target else "系统无",
                                      "仓库有" if has_repo else "仓库无")
            if has_target and has_repo:
                if os.path.getmtime(target) > os.path.getmtime(repo) + 1:
                    text += "（系统更新）"
                elif os.path.getmtime(repo) > os.path.getmtime(target) + 1:
                    text += "（仓库更新）"
            self.dot_tree.insert("", "end", iid=title,
                                 values=(title, item.target_display(), item.repo_display(), text),
                                 tags=("ok" if has_target and has_repo else "bad",))
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
            path, label = item.target_path(), "配置目录"
        elif column == "#3":
            path, label = item.repo_path(), "仓库文件位置"
        else:
            return
        self.open_report(path, label, alert=True, containing=True)

    def dot_action(self, action: str):
        direction = "backup" if action.startswith("backup") else "restore"
        verb = "备份（系统覆盖仓库）" if direction == "backup" else "恢复（仓库覆盖系统）"
        if action.endswith("_all"):
            if not messagebox.askyesno(APP_TITLE, "确认对全部 {0} 项执行{1}？".format(len(DOTFILES), verb)):
                return
            done = sum(1 for item in DOTFILES.values() if self.dot_copy(item, direction, quiet=True))
            self.refresh_dotfiles()
            self.set_status("{0} 完成：{1}/{2}".format(verb, done, len(DOTFILES)))
            return

        item = self.selected_dot()
        if item is None:
            return
        path = item.repo_path() if direction == "backup" else item.target_path()
        if self.dot_copy(item, direction):
            self.set_status("{0}：{1}".format(
                "已备份到仓库" if direction == "backup" else "已从仓库恢复", path))
        self.refresh_dotfiles()

    def dot_copy(self, item: DotFile, direction: str, quiet: bool = False) -> bool:
        target = item.target_path()
        repo = item.repo_path()
        src, dst = (target, repo) if direction == "backup" else (repo, target)
        label = "系统文件" if direction == "backup" else "仓库文件"
        try:
            if not os.path.isfile(src):
                if not quiet:
                    messagebox.showwarning(APP_TITLE, "{0}不存在：{1}".format(label, src))
                return False
            copy_file(src, dst)
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
