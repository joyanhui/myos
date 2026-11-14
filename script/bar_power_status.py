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

POWER_DIR = Path("/sys/class/power_supply")
CACHE_DIR = Path(tempfile.gettempdir()) / "bar-power"
DETAIL_LOCK = "detail.lock"
ASHELL_POLL = 30
LOW_CAPACITY = 20

ICON_CHARGING = "\U000F0241"
ICON_PLUG = "\U000F06A5"
ICON_PLUG_OFF = "\U000F06A6"
LEVEL_ICONS = [
    "\U000F008E",
    "\U000F007A",
    "\U000F007B",
    "\U000F007C",
    "\U000F007D",
    "\U000F007E",
    "\U000F007F",
    "\U000F0080",
    "\U000F0081",
    "\U000F0082",
]

STATE_UNPLUGGED = "unplugged"
STATE_PLUGGED = "plugged"
STATE_CHARGING = "charging"


def read_text(path):
    try:
        return path.read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def read_int(path):
    try:
        return int(float(read_text(path)))
    except (TypeError, ValueError):
        return None


def supplies():
    try:
        return sorted(POWER_DIR.iterdir())
    except OSError:
        return []


def mains_status():
    for entry in supplies():
        if read_text(entry / "type") != "Mains":
            continue
        return {
            "name": entry.name,
            "online": read_text(entry / "online") == "1",
        }
    return {"name": "", "online": False}


def battery_status():
    for entry in supplies():
        if read_text(entry / "type") != "Battery":
            continue
        if read_text(entry / "present") == "0":
            continue
        energy_now = read_int(entry / "energy_now")
        energy_full = read_int(entry / "energy_full")
        energy_design = read_int(entry / "energy_full_design")
        charge_now = read_int(entry / "charge_now")
        charge_full = read_int(entry / "charge_full")
        if energy_now is None:
            energy_now = charge_now
        if energy_full is None:
            energy_full = charge_full
        health = None
        if energy_full and energy_design:
            health = round(energy_full * 100 / energy_design, 1)
        return {
            "name": entry.name,
            "model": read_text(entry / "model_name"),
            "manufacturer": read_text(entry / "manufacturer"),
            "technology": read_text(entry / "technology"),
            "status": read_text(entry / "status") or "Unknown",
            "capacity": read_int(entry / "capacity"),
            "energy_now": energy_now,
            "energy_full": energy_full,
            "energy_design": energy_design,
            "power_now": read_int(entry / "power_now"),
            "voltage_now": read_int(entry / "voltage_now"),
            "cycle_count": read_int(entry / "cycle_count"),
            "health": health,
            "charge_types": read_text(entry / "charge_types"),
            "conservation_mode": read_text(
                Path("/sys/bus/platform/devices/VPC2004:00/conservation_mode")
            ),
        }
    return None


def snapshot():
    mains = mains_status()
    battery = battery_status()
    status = (battery or {}).get("status", "Unknown")
    if not mains["online"]:
        state = STATE_UNPLUGGED
    elif status == "Charging":
        state = STATE_CHARGING
    else:
        state = STATE_PLUGGED
    return {"mains": mains, "battery": battery, "state": state}


def level_icon(capacity):
    if capacity is None:
        return LEVEL_ICONS[0]
    index = min(len(LEVEL_ICONS) - 1, max(0, capacity // 10))
    return LEVEL_ICONS[index]


def battery_icon(data):
    state = data["state"]
    battery = data["battery"] or {}
    capacity = battery.get("capacity")
    if state == STATE_CHARGING:
        return ICON_CHARGING
    if state == STATE_PLUGGED:
        return ICON_PLUG
    return level_icon(capacity)


def bar_text(data):
    battery = data["battery"]
    if not battery:
        return f"{ICON_PLUG_OFF} NO BAT"
    capacity = battery.get("capacity")
    percent = "--" if capacity is None else f"{capacity}%"
    return f"{battery_icon(data)} {percent}"


def state_label(data):
    state = data["state"]
    status = (data["battery"] or {}).get("status", "")
    if state == STATE_CHARGING:
        return "外部电源已连接，正在充电"
    if state == STATE_PLUGGED:
        if status == "Full":
            return "外部电源已连接，电池已充满"
        return "外部电源已连接，未充电"
    return "外部电源未连接，使用电池供电"


def state_class(data):
    battery = data["battery"] or {}
    if data["state"] == STATE_UNPLUGGED:
        capacity = battery.get("capacity")
        if capacity is not None and capacity <= LOW_CAPACITY:
            return "critical"
        return "unplugged"
    return data["state"]


def watts(microwatts):
    if not microwatts:
        return None
    return round(microwatts / 1_000_000, 2)


def watt_hours(microwatt_hours):
    if not microwatt_hours:
        return None
    return round(microwatt_hours / 1_000_000, 1)


def format_duration(seconds):
    if seconds is None or seconds <= 0:
        return ""
    minutes = int(seconds // 60)
    hours = minutes // 60
    minutes = minutes % 60
    if hours:
        return f"{hours}h{minutes:02d}m"
    return f"{minutes}m"


def remaining_text(data):
    battery = data["battery"] or {}
    energy_now = battery.get("energy_now")
    energy_full = battery.get("energy_full")
    power = battery.get("power_now")
    if not energy_now or not power:
        return ""
    if data["state"] == STATE_CHARGING:
        if not energy_full or energy_full <= energy_now:
            return ""
        return format_duration((energy_full - energy_now) * 3600 / power)
    return format_duration(energy_now * 3600 / power)


def detail_lines(data):
    battery = data["battery"] or {}
    mains = data["mains"]
    lines = [state_label(data)]
    if mains["name"]:
        lines.append(f"适配器 {mains['name']}: {'已连接' if mains['online'] else '未连接'}")
    if not battery:
        lines.append("未检测到电池")
        return lines
    model = " ".join(part for part in (battery.get("manufacturer"), battery.get("model")) if part)
    if model:
        lines.append(f"电池 {battery['name']}: {model}")
    capacity = battery.get("capacity")
    if capacity is not None:
        lines.append(f"电量: {capacity}%")
    energy_now = watt_hours(battery.get("energy_now"))
    energy_full = watt_hours(battery.get("energy_full"))
    if energy_now is not None and energy_full:
        lines.append(f"能量: {energy_now} Wh / {energy_full} Wh")
    if battery.get("health") is not None:
        design = watt_hours(battery.get("energy_design"))
        extra = f"，设计 {design} Wh" if design else ""
        lines.append(f"健康度: {battery['health']}%{extra}")
    if battery.get("cycle_count") is not None:
        lines.append(f"循环次数: {battery['cycle_count']}")
    power = watts(battery.get("power_now"))
    if power:
        lines.append(f"当前功率: {power} W")
    voltage = battery.get("voltage_now")
    if voltage:
        lines.append(f"电压: {round(voltage / 1_000_000, 2)} V")
    duration = remaining_text(data)
    if duration:
        label = "预计充满" if data["state"] == STATE_CHARGING else "预计可用"
        lines.append(f"{label}: {duration}")
    lines.append(f"内核状态: {battery.get('status', 'Unknown')}")
    if battery.get("charge_types"):
        lines.append(f"充电模式: {battery['charge_types']}")
    if battery.get("conservation_mode"):
        mode = "开启" if battery["conservation_mode"] == "1" else "关闭"
        lines.append(f"保养模式: {mode}")
    lines.append(f"更新时间: {time.strftime('%m-%d %H:%M:%S')}")
    return lines


def tooltip(data):
    return "\n".join(detail_lines(data))


def payload_text(data):
    return {"text": bar_text(data), "alt": data["state"]}


def print_waybar():
    data = snapshot()
    print(
        json.dumps(
            {
                "text": bar_text(data),
                "tooltip": tooltip(data),
                "class": state_class(data),
            },
            ensure_ascii=False,
        )
    )


def print_ashell():
    print(json.dumps(payload_text(snapshot()), ensure_ascii=False), flush=True)


def listen_ashell():
    last = None
    while True:
        payload = payload_text(snapshot())
        if payload != last:
            print(json.dumps(payload, ensure_ascii=False), flush=True)
            last = payload
        time.sleep(ASHELL_POLL)


POPUP_BG = "#121619"
POPUP_PANEL = "#1b2226"
POPUP_FG = "#e3e8e2"
POPUP_ACCENT = "#a8d5b5"
POPUP_FONT = "Noto Sans Mono CJK SC"

POWER_PROFILES = [
    ("power-saver", "节能"),
    ("balanced", "平衡"),
    ("performance", "性能"),
]


def power_profile_available():
    return shutil.which("powerprofilesctl") is not None


def power_profile():
    try:
        result = subprocess.run(
            ["powerprofilesctl", "get"],
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    if result.returncode != 0:
        return ""
    return result.stdout.strip()


def set_power_profile(name):
    try:
        subprocess.run(
            ["powerprofilesctl", "set", name],
            capture_output=True,
            text=True,
            timeout=5,
        )
    except (OSError, subprocess.SubprocessError):
        return False
    return True


def profile_label():
    current = power_profile()
    for name, label in POWER_PROFILES:
        if name == current:
            return f"电源模式: {label}"
    return "电源模式: 未知"


def next_profile():
    names = [name for name, _label in POWER_PROFILES]
    current = power_profile()
    if current in names:
        return names[(names.index(current) + 1) % len(names)]
    return names[0]


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
        ch for ch in str(text) if not (0xE000 <= ord(ch) <= 0xF8FF or ord(ch) >= 0xF0000)
    )


def run_detail():
    if not popup_ready():
        print(tooltip(snapshot()))
        return
    lock = popup_lock(DETAIL_LOCK)
    if lock is None:
        return
    import tkinter as tk

    root = tk.Tk()
    root.title("电源状态")
    root.configure(bg=POPUP_BG)
    root.resizable(False, False)
    screen_w, screen_h = root.winfo_screenwidth(), root.winfo_screenheight()
    width, height = 620, 620
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
        font=(POPUP_FONT, 15),
        cursor="arrow",
    )
    body.pack(fill="both", expand=True, padx=12, pady=(12, 6))
    body.insert("1.0", plain_text(tooltip(snapshot())))
    body.configure(state="disabled")
    buttons = tk.Frame(root, bg=POPUP_BG)
    buttons.pack(fill="x", padx=12, pady=(0, 12))

    def reload():
        body.configure(state="normal")
        body.delete("1.0", "end")
        body.insert("1.0", plain_text(tooltip(snapshot())))
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

    if power_profile_available():

        def cycle_profile():
            set_power_profile(next_profile())
            profile_button.configure(text=profile_label())
            reload()

        profile_button = button(buttons, profile_label(), cycle_profile)
        profile_button.pack(side="left", padx=(10, 0))

    button(buttons, "关闭", root.destroy).pack(side="right")
    root.mainloop()
    lock.close()


def main():
    args = sys.argv[1:]
    mode = args[0] if args else "--text"
    if mode == "--text":
        print(bar_text(snapshot()))
        return
    if mode == "--json":
        print(json.dumps(snapshot(), ensure_ascii=False))
        return
    if mode == "--waybar":
        print_waybar()
        return
    if mode == "--tooltip":
        print(tooltip(snapshot()))
        return
    if mode == "--ashell":
        print_ashell()
        return
    if mode == "--ashell-listen":
        listen_ashell()
        return
    if mode == "--detail":
        run_detail()
        return
    sys.exit(f"unknown option: {mode}")


if __name__ == "__main__":
    main()
