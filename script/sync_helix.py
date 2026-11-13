#!/usr/bin/env python3
from __future__ import annotations

import argparse
import base64
import getpass
import io
import os
import re
import shlex
import shutil
import subprocess
import sys
import tarfile
import time
from pathlib import Path

REPO_DIR = Path(__file__).resolve().parent.parent
DOTFILES_DIR = REPO_DIR / "dotfiles"
FULL_FILES = {
    "config.toml": DOTFILES_DIR / "helix_config.toml",
    "languages.toml": DOTFILES_DIR / "helix_languages.toml",
}
REMOTE_DIR = ".config/helix"
SSH_OPTS = [
    "-o",
    "ConnectTimeout=10",
    "-o",
    "StrictHostKeyChecking=accept-new",
    "-o",
    "ServerAliveInterval=15",
    "-o",
    "ServerAliveCountMax=3",
    "-o",
    "LogLevel=ERROR",
]
HEALTH_LANGUAGES = [
    "bash",
    "fish",
    "python",
    "javascript",
    "typescript",
    "json",
    "yaml",
    "toml",
    "nix",
    "lua",
    "go",
    "rust",
    "c",
    "html",
    "css",
    "markdown",
]
PROBE_TOOLS = [
    "hx",
    "tar",
    "base64",
    "openssl",
    "opkg",
    "apk",
    "apt-get",
    "dnf",
    "pacman",
    "nix-env",
]
INSTALL_HINTS = {
    "opkg": "opkg update && opkg install helix",
    "apk": "apk add helix",
    "apt-get": "apt-get install helix",
    "dnf": "dnf install helix",
    "pacman": "pacman -S helix",
    "nix-env": "nix profile install nixpkgs#helix",
}
ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")
BASIC_CONFIG = """theme = "default"

[editor]
line-number = "relative"
cursorline = true
bufferline = "multiple"
rulers = [80, 100]
scrolloff = 5
auto-format = false
soft-wrap.enable = true
popup-border = "all"

[editor.cursor-shape]
insert = "bar"
normal = "block"
select = "underline"

[editor.indent-guides]
render = true
character = "\u2502"
skip-levels = 1

[editor.statusline]
left = ["mode", "spinner", "file-name", "read-only-indicator", "file-modification-indicator"]
center = ["file-type"]
right = ["diagnostics", "selections", "position", "file-encoding", "file-line-ending"]
"""


class SyncError(Exception):
    pass


def log(message: str) -> None:
    print(message, flush=True)


def build_ssh_args(port: int | None, identity: str | None) -> list[str]:
    args = ["ssh"] + list(SSH_OPTS)
    if port:
        args += ["-p", str(port)]
    if identity:
        args += ["-i", identity]
    return args


def run(args: list[str], stdin: bytes = b"", env: dict | None = None, timeout: int = 180):
    try:
        return subprocess.run(
            args,
            input=stdin,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=env,
            timeout=timeout,
        )
    except FileNotFoundError as exc:
        raise SyncError(f"command not found: {args[0]}") from exc


def check_key_auth(args: list[str], target: str) -> tuple[bool, str]:
    proc = run(
        args + ["-o", "BatchMode=yes", "-o", "NumberOfPasswordPrompts=0", target, "true"],
        timeout=45,
    )
    return proc.returncode == 0, proc.stderr.decode(errors="replace").strip()


class Remote:
    def __init__(self, target: str, args: list[str], password: str | None = None) -> None:
        self.target = target
        self.env = os.environ.copy()
        self.args = args
        if password:
            if not shutil.which("sshpass"):
                raise SyncError("sshpass not found, install sshpass or configure ssh key auth")
            self.args = ["sshpass", "-e"] + args
            self.env["SSHPASS"] = password

    def exec(self, command: str, stdin: bytes = b"", timeout: int = 180):
        return run(self.args + [self.target, command], stdin=stdin, env=self.env, timeout=timeout)

    def exec_script(self, script: str, timeout: int = 180):
        return self.exec("sh -s", stdin=script.encode(), timeout=timeout)


def connect(target: str, args: list[str]) -> Remote:
    ok, err = check_key_auth(args, target)
    if ok:
        return Remote(target, args)
    if any(word in err for word in ("Host key verification failed", "Could not resolve hostname", "Connection refused", "Connection timed out", "No route to host")):
        raise SyncError(f"cannot connect to {target}: {err.splitlines()[0] if err else 'unknown error'}")
    if not sys.stdin.isatty():
        raise SyncError("password required but stdin is not a terminal")
    for attempt in range(1, 4):
        password = getpass.getpass(f"password for {target} ({attempt}/3): ")
        if not password:
            continue
        remote = Remote(target, args, password)
        proc = remote.exec("true", timeout=45)
        if proc.returncode == 0:
            return remote
        log("auth failed")
    raise SyncError("authentication failed")


def health_languages(files: dict[str, bytes]) -> list[str]:
    if "languages.toml" not in files:
        return [lang for lang in HEALTH_LANGUAGES if lang != "nix"]
    return list(HEALTH_LANGUAGES)


def new_health_state() -> dict:
    return {"parser": True, "queries": True, "known": True}


def probe(remote: Remote, tools: list[str], languages: list[str]) -> tuple[dict, str]:
    tool_words = " ".join(shlex.quote(tool) for tool in tools)
    lang_words = " ".join(shlex.quote(lang) for lang in languages)
    script = (
        f'printf "home|%s\\n" "$HOME"\n'
        f'printf "arch|%s\\n" "$(uname -m 2>/dev/null)"\n'
        f'for c in {tool_words}; do\n'
        f'  if command -v "$c" >/dev/null 2>&1; then printf "tool|%s\\n" "$c"; fi\n'
        f"done\n"
        f'if command -v hx >/dev/null 2>&1; then\n'
        f'  printf "version|%s\\n" "$(hx --version 2>/dev/null | head -n 1)"\n'
        f"  for l in {lang_words}; do\n"
        f'    printf "lang_begin|%s\\n" "$l"\n'
        f'    hx --health "$l" 2>&1\n'
        f"    printf 'lang_end\\n'\n"
        f"  done\n"
        f"fi\n"
    )
    proc = remote.exec_script(script)
    if proc.returncode != 0 and not proc.stdout:
        raise SyncError(f"remote probe failed: {proc.stderr.decode(errors='replace').strip()}")
    info: dict = {"tools": set(), "version": "", "langs": {}}
    current = ""
    state = new_health_state()
    for raw in proc.stdout.decode(errors="replace").splitlines():
        line = ANSI_RE.sub("", raw).strip()
        if line.startswith("lang_begin|"):
            current = line.split("|", 1)[1]
            state = new_health_state()
            continue
        if line == "lang_end":
            if current:
                info["langs"][current] = state["known"] and state["parser"] and state["queries"]
            current = ""
            continue
        if current:
            if line.lower().startswith("language ") and "not found" in line.lower():
                state["known"] = False
            elif line.startswith("Tree-sitter parser"):
                state["parser"] = "\u2713" in line
            elif line.startswith("Highlight queries"):
                state["queries"] = "\u2713" in line
            continue
        tag, _, value = line.partition("|")
        if tag == "tool":
            info["tools"].add(value.strip())
        elif tag in ("home", "arch", "version"):
            info[tag] = value.strip()
    return info, proc.stderr.decode(errors="replace").strip()


def collect_commands(paths: list[Path]) -> list[str]:
    found: set[str] = set()
    for path in paths:
        try:
            text = path.read_text(encoding="utf-8")
        except OSError as exc:
            raise SyncError(f"cannot read {path}: {exc}") from exc
        for value in re.findall(r'command\s*=\s*"([^"]+)"', text):
            if value and " " not in value:
                found.add(value)
    return sorted(found)


def load_files(mode: str) -> dict[str, bytes]:
    if mode == "basic":
        return {"config.toml": BASIC_CONFIG.encode()}
    files: dict[str, bytes] = {}
    for name, source in FULL_FILES.items():
        try:
            data = source.read_bytes()
        except OSError as exc:
            raise SyncError(f"cannot read {source}: {exc}") from exc
        if not data.strip():
            raise SyncError(f"{source} is empty")
        files[name] = data
    return files


def build_tar(files: dict[str, bytes]) -> bytes:
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w") as archive:
        for name, data in files.items():
            info = tarfile.TarInfo(name)
            info.size = len(data)
            info.mode = 0o644
            info.mtime = int(time.time())
            archive.addfile(info, io.BytesIO(data))
    return buffer.getvalue()


def install_script(mode: str) -> str:
    languages_action = "mv" if mode == "basic" else "cp"
    return (
        '[ -n "$HOME" ] || HOME=$(cd ~ && pwd)\n'
        'd="$HOME/%s"\n'
        'mkdir -p "$d" || exit 1\n'
        'ts=$(date +%%Y%%m%%d%%H%%M%%S 2>/dev/null)\n'
        '[ -n "$ts" ] || ts=manual\n'
        "backed=0\n"
        'if [ -f "$d/config.toml" ]; then\n'
        '  cp "$d/config.toml" "$d/config.toml.bak.$ts" || exit 1\n'
        "  backed=1\n"
        "fi\n"
        'if [ -f "$d/languages.toml" ]; then\n'
        '  %s "$d/languages.toml" "$d/languages.toml.bak.$ts" || exit 1\n'
        "  backed=1\n"
        "fi\n"
        'if [ "$backed" = 1 ]; then printf "backup|%%s\\n" "$ts"; fi\n'
    ) % (REMOTE_DIR, languages_action)


def upload_tar(remote: Remote, files: dict[str, bytes]) -> bool:
    payload = build_tar(files)
    command = 'mkdir -p "$HOME/%s" && tar -xf - -C "$HOME/%s"' % (REMOTE_DIR, REMOTE_DIR)
    proc = remote.exec(command, stdin=payload)
    if proc.returncode == 0:
        return True
    log(f"tar upload failed: {proc.stderr.decode(errors='replace').strip()}")
    return False


def upload_base64(remote: Remote, files: dict[str, bytes]) -> bool:
    lines = [
        'd="$HOME/%s"' % REMOTE_DIR,
        'mkdir -p "$d" || exit 1',
        'if command -v base64 >/dev/null 2>&1; then dec="base64 -d"',
        'elif command -v openssl >/dev/null 2>&1; then dec="openssl base64 -d"',
        'else echo "no base64 decoder" >&2; exit 3; fi',
    ]
    for name, data in files.items():
        encoded = base64.b64encode(data).decode()
        lines.append(
            "printf '%%s' '%s' | $dec > \"$d/%s\" || exit 1" % (encoded, name)
        )
    proc = remote.exec_script("\n".join(lines) + "\n")
    if proc.returncode == 0:
        return True
    log(f"base64 upload failed: {proc.stderr.decode(errors='replace').strip()}")
    return False


def verify(remote: Remote, files: dict[str, bytes]) -> list[str]:
    names = " ".join(shlex.quote(name) for name in files)
    script = (
        'd="$HOME/%s"\n'
        'for f in %s; do printf "file|%%s|%%s\\n" "$f" "$(wc -c < "$d/$f" 2>/dev/null)"; done\n'
    ) % (REMOTE_DIR, names)
    proc = remote.exec_script(script)
    sizes: dict[str, int] = {}
    for line in proc.stdout.decode(errors="replace").splitlines():
        tag, _, rest = line.partition("|")
        if tag != "file":
            continue
        name, _, size = rest.rpartition("|")
        try:
            sizes[name] = int(size.strip())
        except ValueError:
            sizes[name] = -1
    problems = []
    for name, data in files.items():
        remote_size = sizes.get(name, -1)
        if remote_size != len(data):
            problems.append(f"{name}: local {len(data)} bytes, remote {remote_size}")
    return problems


def render_summary(languages: dict) -> str:
    if not languages:
        return "no language check"
    ok = [lang for lang, ready in languages.items() if ready]
    missing = [lang for lang, ready in languages.items() if not ready]
    if not missing:
        return f"{len(ok)}/{len(languages)} languages render ok"
    return f"{len(ok)}/{len(languages)} languages render ok, missing grammars: {' '.join(missing)}"


def version_tuple(text: str) -> tuple:
    match = re.search(r"(\d+)\.(\d+)", text or "")
    if not match:
        return ()
    return (int(match.group(1)), int(match.group(2)))


def dependency_report(info: dict, required: list[str]) -> None:
    tools = info.get("tools", set())
    missing = [tool for tool in required if tool not in tools]
    if not required:
        return
    log("remote dependencies:")
    for tool in required:
        log(f"  {'ok     ' if tool in tools else 'missing'} {tool}")
    if missing:
        log("  note: helix still edits fine, only format/lsp features are skipped")


def install_hint(info: dict) -> str:
    tools = info.get("tools", set())
    for manager in ("opkg", "apk", "apt-get", "dnf", "pacman", "nix-env"):
        if manager in tools:
            return INSTALL_HINTS[manager]
    return "install helix with the system package manager"


def pick_mode(args) -> str:
    if args.mode:
        return args.mode
    if not sys.stdin.isatty():
        return "basic"
    log("helix config mode:")
    log("  1) basic  minimal config, no external tools, suits routers and low-end hosts")
    log("  2) full   verbatim copy of dotfiles/helix_config.toml and helix_languages.toml")
    while True:
        answer = input("select mode [1]: ").strip() or "1"
        if answer in ("1", "basic"):
            return "basic"
        if answer in ("2", "full"):
            return "full"
        log("invalid choice")


def pick_target(args) -> str:
    if args.host:
        return args.host
    if not sys.stdin.isatty():
        raise SyncError("ssh target missing, pass --host user@ip")
    while True:
        answer = input("ssh target (user@ip): ").strip()
        if answer:
            return answer
        log("target cannot be empty")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Sync a Helix editor configuration to a remote host over ssh.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "examples:\n"
            "  sync_helix.py\n"
            "  sync_helix.py --host root@192.168.1.1 --mode basic\n"
            "  sync_helix.py --host me@server -p 2222 --mode full\n"
            "  sync_helix.py --print-config\n"
        ),
    )
    parser.add_argument("--host", help="ssh target, for example user@ip or a ~/.ssh/config alias")
    parser.add_argument("--mode", choices=("basic", "full"), help="basic or full config set")
    parser.add_argument("-p", "--port", type=int, help="ssh port")
    parser.add_argument("-i", "--identity", help="ssh private key")
    parser.add_argument("--print-config", action="store_true", help="print the basic config and exit")
    parser.add_argument("--no-health", action="store_true", help="skip the remote tree-sitter check")
    args = parser.parse_args()

    if args.print_config:
        sys.stdout.write(BASIC_CONFIG)
        return 0

    try:
        mode = pick_mode(args)
        files = load_files(mode)
        formatter_tools = collect_commands(list(FULL_FILES.values())) if mode == "full" else []
        required = sorted(set(PROBE_TOOLS) | set(formatter_tools))
        target = pick_target(args)
        log(f"target {target} mode {mode}")
        log("files: " + ", ".join(f"{name} ({len(data)} bytes)" for name, data in files.items()))

        languages = [] if args.no_health else health_languages(files)
        args_ssh = build_ssh_args(args.port, args.identity)
        remote = connect(target, args_ssh)
        info, err = probe(remote, required, languages)
        if not info.get("home"):
            raise SyncError(f"remote probe returned no home directory: {err}")
        log(f"remote {info.get('arch') or 'unknown arch'} home {info['home']}")
        log(f"helix {info.get('version') or 'not installed'}")

        proc = remote.exec_script(install_script(mode))
        if proc.returncode != 0:
            raise SyncError(f"remote prepare failed: {proc.stderr.decode(errors='replace').strip()}")
        backup = ""
        for line in proc.stdout.decode(errors="replace").splitlines():
            tag, _, value = line.partition("|")
            if tag == "backup":
                backup = value.strip()
        if backup:
            log(f"remote backup suffix .bak.{backup}")

        if "tar" in info["tools"] and upload_tar(remote, files):
            log("uploaded via tar")
        elif upload_base64(remote, files):
            log("uploaded via base64")
        else:
            raise SyncError("upload failed, remote needs tar or base64")

        problems = verify(remote, files)
        if problems:
            for problem in problems:
                log(f"verify mismatch: {problem}")
            raise SyncError("verification failed")

        log(f"installed into {info['home']}/{REMOTE_DIR}")
        if "hx" not in info["tools"]:
            log(f"helix not found on remote, {install_hint(info)}")
        elif languages:
            log(f"render check: {render_summary(info.get('langs', {}))}")
            version = version_tuple(info.get("version", ""))
            if version and version < (23, 5):
                log("warning: remote helix is old, some config keys may be ignored")
        dependency_report(info, formatter_tools)
        return 0
    except SyncError as exc:
        log(f"error: {exc}")
        return 1
    except KeyboardInterrupt:
        log("aborted")
        return 130


if __name__ == "__main__":
    sys.exit(main())
