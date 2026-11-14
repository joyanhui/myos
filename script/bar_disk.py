#!/usr/bin/env python3
import fcntl
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

CACHE_DIR = Path(tempfile.gettempdir()) / "bar-disk"
DETAIL_LOCK = "detail.lock"

COLOR_ALERT = "#f87171"
COLOR_MID = "#b07d4e"
LOW_FREE_RED = 10
LOW_FREE_BROWN = 25

WATCHED_PATHS = ("/", "/home")
VIRTUAL_PREFIXES = ("loop", "zram", "ram", "sr", "dm-", "nbd", "md", "fd")


def human_bytes(value, digits=1):
    if value is None:
        return "--"
    units = ("B", "K", "M", "G", "T", "P")
    size = float(value)
    for unit in units:
        if abs(size) < 1024 or unit == units[-1]:
            if unit == "B":
                return f"{int(size)}{unit}"
            return f"{size:.{digits}f}{unit}" if size < 10 else f"{size:.0f}{unit}"
        size /= 1024
    return f"{size:.1f}P"


def percent_color(percent):
    if percent is None:
        return None
    free = 100 - percent
    if free <= LOW_FREE_RED:
        return COLOR_ALERT
    if free <= LOW_FREE_BROWN:
        return COLOR_MID
    return None


def badge(text, color=None):
    attrs = ' size="+2"'
    if color:
        attrs += f' color="{color}"'
    return f"<font{attrs}>{text}</font>"


def usage_of(path):
    try:
        usage = shutil.disk_usage(path)
    except OSError:
        return None
    if not usage.total:
        return None
    percent = round(usage.used * 100 / usage.total)
    return {
        "path": path,
        "total": usage.total,
        "used": usage.used,
        "free": usage.free,
        "percent": percent,
        "color": percent_color(percent),
    }


def filesystems():
    entries = []
    seen = set()
    for path in WATCHED_PATHS:
        if not os.path.isdir(path):
            continue
        try:
            device = os.stat(path).st_dev
        except OSError:
            continue
        if device in seen:
            continue
        seen.add(device)
        usage = usage_of(path)
        if usage:
            entries.append(usage)
    return entries


def bar_text(rich=False):
    entries = filesystems()
    if not entries:
        return "N/A"
    parts = []
    for entry in entries:
        percent = f"{entry['percent']}%"
        free = human_bytes(entry["free"], 0)
        if rich and entry["color"]:
            parts.append(
                entry["path"] + " " + badge(percent, entry["color"]) + " " + free
            )
        else:
            parts.append(f"{entry['path']} {percent} {free}")
    rich_text = "  ".join(parts)
    plain = plain_text(rich_text)
    if len(plain) > 50:
        return "  ".join(
            f"{e['path']} {e['percent']}% {human_bytes(e['free'], 0)}"
            for e in entries
        )
    return rich_text


def run(cmd, timeout=8):
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.SubprocessError):
        return None
    return result


def lsblk_disks():
    result = run(["lsblk", "-J", "-b", "-o", "NAME,TYPE,SIZE,MODEL,SERIAL,VENDOR,TRAN,ROTA,MOUNTPOINTS,FSUSE%,FSTYPE,RO"])
    if result is None or result.returncode != 0:
        return []
    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError:
        return []
    return [
        device
        for device in data.get("blockdevices", [])
        if device.get("type") == "disk"
        and not str(device.get("name", "")).startswith(VIRTUAL_PREFIXES)
    ]


def smartctl_json(device):
    command = ["smartctl", "-a", "-j", f"/dev/{device}"]
    result = run(command)
    if result is None:
        return None
    if result.returncode & 2 or "Permission denied" in (result.stderr + result.stdout):
        if os.geteuid() != 0:
            result = run(["sudo", "-n"] + command)
            if result is None:
                return None
    if not result.stdout.strip():
        return None
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return None


def nvme_temperature(device):
    base = Path("/sys/class/nvme") / device
    for hwmon in sorted(base.glob("hwmon*")):
        try:
            return round(int((hwmon / "temp1_input").read_text().strip()) / 1000)
        except (OSError, ValueError):
            continue
    return None


def ata_attributes(smart):
    attributes = {}
    table = smart.get("ata_smart_attributes", {}).get("table", [])
    for row in table:
        name = row.get("name")
        if name:
            attributes[name] = row.get("raw", {}).get("value", row.get("value"))
    return attributes


def disk_smart(device):
    smart = smartctl_json(device)
    info = {
        "device": device,
        "health": "",
        "temperature": None,
        "power_on_hours": None,
        "power_cycles": None,
        "life_used": None,
        "spare": None,
        "written": None,
        "read": None,
        "media_errors": None,
        "reallocated": None,
        "pending": None,
        "errors_logged": None,
        "available": smart is not None,
    }
    if smart is None:
        info["temperature"] = nvme_temperature(device)
        return info
    passed = smart.get("smart_status", {}).get("passed")
    if passed is True:
        info["health"] = "PASSED"
    elif passed is False:
        info["health"] = "FAILED"
    nvme = smart.get("nvme_smart_health_information_log", {})
    if nvme:
        info["temperature"] = nvme.get("temperature")
        info["power_on_hours"] = nvme.get("power_on_hours")
        info["power_cycles"] = nvme.get("power_cycles")
        life = nvme.get("percentage_used")
        info["life_used"] = None if life is None else min(100, life)
        info["spare"] = nvme.get("available_spare")
        units = nvme.get("data_units_written")
        if units is not None:
            info["written"] = units * 512 * 1000
        units_read = nvme.get("data_units_read")
        if units_read is not None:
            info["read"] = units_read * 512 * 1000
        info["media_errors"] = nvme.get("media_errors")
    else:
        attributes = ata_attributes(smart)
        info["temperature"] = smart.get("temperature", {}).get("current")
        info["power_on_hours"] = attributes.get("Power_On_Hours")
        info["power_cycles"] = attributes.get("Power_Cycle_Count")
        info["reallocated"] = attributes.get("Reallocated_Sector_Ct")
        info["pending"] = attributes.get("Current_Pending_Sector")
        info["errors_logged"] = smart.get("ata_smart_error_log", {}).get("summary", {}).get(
            "count"
        )
    if info["temperature"] is None:
        info["temperature"] = nvme_temperature(device)
    return info


def disk_entries():
    entries = []
    for device in lsblk_disks():
        name = device.get("name", "")
        entry = {
            "name": name,
            "size": device.get("size"),
            "model": (device.get("model") or "").strip(),
            "vendor": (device.get("vendor") or "").strip(),
            "serial": (device.get("serial") or "").strip(),
            "tran": (device.get("tran") or "").strip(),
            "rota": device.get("rota"),
            "smart": disk_smart(name),
            "children": [],
        }
        for child in device.get("children", []) or []:
            if child.get("type") != "part":
                continue
            mounts = child.get("mountpoints") or []
            entry["children"].append(
                {
                    "name": child.get("name", ""),
                    "size": child.get("size"),
                    "fstype": child.get("fstype") or "",
                    "mountpoints": [m for m in mounts if m],
                }
            )
        entries.append(entry)
    return entries


def detail_lines():
    lines = []
    for entry in filesystems():
        icon = "家目录" if entry["path"] == "/home" else "根分区"
        lines.append(
            f"{icon} {entry['path']}: 已用 {entry['percent']}%，剩余 {human_bytes(entry['free'])} / 总计 {human_bytes(entry['total'])}"
        )
    lines.append("")
    disks = disk_entries()
    if not disks:
        lines.append("未检测到物理磁盘")
        return lines
    for disk in disks:
        smart = disk["smart"]
        kind = "机械盘" if disk["rota"] == "1" or disk["rota"] is True else "固态盘"
        title = " ".join(part for part in (disk["vendor"], disk["model"]) if part)
        lines.append(f"【{disk['name']}】{title or '未知型号'}")
        lines.append(
            f"  类型: {kind}"
            + (f"，接口: {disk['tran']}" if disk["tran"] else "")
            + f"，容量: {human_bytes(disk['size'])}"
        )
        if disk["serial"]:
            lines.append(f"  序列号: {disk['serial']}")
        health = smart.get("health") or "未知"
        if smart.get("life_used") is not None:
            health += f"，寿命已用 {smart['life_used']}%"
        lines.append(f"  SMART 健康: {health}")
        if smart.get("temperature") is not None:
            lines.append(f"  温度: {smart['temperature']} °C")
        if smart.get("power_on_hours") is not None:
            hours = smart["power_on_hours"]
            lines.append(f"  通电时间: {hours} 小时（{hours // 24} 天）")
        if smart.get("power_cycles") is not None:
            lines.append(f"  通电次数: {smart['power_cycles']}")
        if smart.get("spare") is not None:
            lines.append(f"  可用备用空间: {smart['spare']}%")
        if smart.get("written") is not None:
            lines.append(f"  累计写入: {human_bytes(smart['written'])}")
        if smart.get("read") is not None:
            lines.append(f"  累计读取: {human_bytes(smart['read'])}")
        if smart.get("media_errors") is not None:
            lines.append(f"  介质错误: {smart['media_errors']}")
        if smart.get("reallocated") is not None:
            lines.append(f"  重映射扇区: {smart['reallocated']}")
        if smart.get("pending") is not None:
            lines.append(f"  待映射扇区: {smart['pending']}")
        if smart.get("errors_logged") is not None:
            lines.append(f"  ATA 错误日志: {smart['errors_logged']} 条")
        if not smart.get("available"):
            lines.append("  SMART 数据不可用（需要 smartctl 及权限）")
        for child in disk["children"]:
            mounts = " ".join(child["mountpoints"]) or "未挂载"
            lines.append(
                f"  分区 {child['name']}: {human_bytes(child['size'])}"
                + (f" {child['fstype']}" if child["fstype"] else "")
                + f"，挂载 {mounts}"
            )
        lines.append("")
    lines.append(f"更新时间: {time.strftime('%m-%d %H:%M:%S')}")
    return lines


def space_class():
    entries = filesystems()
    if not entries:
        return "warn"
    free = min(100 - entry["percent"] for entry in entries)
    if free <= LOW_FREE_RED:
        return "error"
    if free <= LOW_FREE_BROWN:
        return "warn"
    return "ok"


def print_shell_json():
    print(
        json.dumps(
            {
                "text": bar_text(),
                "tooltip": tooltip(),
                "class": space_class(),
            },
            ensure_ascii=False,
        )
    )


def tooltip():
    return "\n".join(detail_lines())


POPUP_BG = "#121619"
POPUP_PANEL = "#1b2226"
POPUP_FG = "#e3e8e2"
POPUP_ACCENT = "#a8d5b5"
POPUP_FONT = "Noto Sans Mono CJK SC"


def popup_lock(name):
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    handle = open(CACHE_DIR / name, "w")
    try:
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        handle.close()
        return None
    return handle


def popup_ready():
    if not (os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY")):
        return False
    try:
        import tkinter  # noqa: F401
    except Exception:
        return False
    return True


def plain_text(text):
    return "".join(
        ch
        for ch in str(text)
        if not (0xE000 <= ord(ch) <= 0xF8FF or ord(ch) >= 0xF0000)
    )


def run_detail():
    if not popup_ready():
        print(tooltip())
        return
    lock = popup_lock(DETAIL_LOCK)
    if lock is None:
        return
    import tkinter as tk

    root = tk.Tk()
    root.title("磁盘状态")
    root.configure(bg=POPUP_BG)
    root.resizable(False, False)
    screen_w, screen_h = root.winfo_screenwidth(), root.winfo_screenheight()
    width, height = 760, 640
    root.geometry(
        f"{width}x{height}+{(screen_w - width) // 2}+{(screen_h - height) // 3}"
    )
    root.attributes("-topmost", True)
    root.bind("<Escape>", lambda _event: root.destroy())
    body = tk.Text(
        root,
        bg=POPUP_PANEL,
        fg=POPUP_FG,
        relief="flat",
        bd=0,
        highlightthickness=0,
        padx=18,
        pady=16,
        wrap="word",
        height=24,
        font=(POPUP_FONT, 14),
        cursor="arrow",
    )
    body.insert("1.0", plain_text(tooltip()))
    body.configure(state="disabled")
    buttons = tk.Frame(root, bg=POPUP_BG)
    buttons.pack(side="bottom", fill="x", padx=12, pady=(0, 12))
    body.pack(fill="both", expand=True, padx=12, pady=(12, 6))

    def reload():
        body.configure(state="normal")
        body.delete("1.0", "end")
        body.insert("1.0", plain_text(tooltip()))
        body.configure(state="disabled")

    def button(parent, text, command):
        return tk.Button(
            parent,
            text=text,
            command=command,
            bg=POPUP_PANEL,
            fg=POPUP_FG,
            activebackground=POPUP_ACCENT,
            activeforeground=POPUP_BG,
            relief="flat",
            bd=0,
            padx=18,
            pady=10,
            font=(POPUP_FONT, 14),
            cursor="hand2",
        )

    button(buttons, "刷新", reload).pack(side="left")
    button(buttons, "关闭", root.destroy).pack(side="right")
    root.mainloop()
    lock.close()


def main():
    args = sys.argv[1:]
    mode = args[0] if args else "--text"
    if mode == "--text":
        print(bar_text(rich=True))
        return
    if mode == "--plain":
        print(bar_text(rich=False))
        return
    if mode == "--waybar":
        print_shell_json()
        return
    if mode == "--noctalia":
        print_shell_json()
        return
    if mode == "--json":
        print(
            json.dumps(
                {"filesystems": filesystems(), "disks": disk_entries()},
                ensure_ascii=False,
            )
        )
        return
    if mode == "--tooltip":
        print(tooltip())
        return
    if mode == "--detail":
        run_detail()
        return
    print(bar_text(rich=True))


if __name__ == "__main__":
    main()
