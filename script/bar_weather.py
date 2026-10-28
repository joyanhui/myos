#!/usr/bin/env python3
import fcntl
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import date
from pathlib import Path

API_URL = "https://api.weatherapi.com/v1/forecast.json"
PLACEHOLDER_KEY = "PLACEHOLDER_WEATHERAPI_API_KEY"
CACHE_DIR = Path(tempfile.gettempdir()) / "bar-weather"
ACTIVE_FILE = "active_city"
KEY_FLAG = "apikey_invalid"
DETAIL_LOCK = "detail.lock"
PICKER_LOCK = "picker.lock"
TTL_OK = 1800
FORECAST_DAYS = 3
WEEKDAYS = ("周一", "周二", "周三", "周四", "周五", "周六", "周日")
TTL_FAIL = 300
HTTP_TIMEOUT = 8
DEFAULT_CITY = "taian"

CITIES = [
    {"id": "taian", "name": "山东泰安", "short": "泰安", "lat": 36.1996, "lon": 117.0890},
    {"id": "linyi", "name": "山东临沂", "short": "临沂", "lat": 35.1045, "lon": 118.3564},
    {"id": "shantou", "name": "广东汕头", "short": "汕头", "lat": 23.3535, "lon": 116.6822},
    {"id": "kyoto", "name": "日本京都", "short": "京都", "lat": 35.0116, "lon": 135.7681},
    {"id": "shanghai", "name": "上海市", "short": "上海", "lat": 31.2304, "lon": 121.4737},
    {"id": "penang", "name": "马来西亚滨城", "short": "滨城", "lat": 5.4200, "lon": 100.3300},
]

ICON_SUNNY = "\U000F0599"
ICON_PARTLY = "\U000F0595"
ICON_CLOUDY = "\U000F0590"
ICON_FOG = "\U000F0591"
ICON_RAINY = "\U000F0597"
ICON_POURING = "\U000F0596"
ICON_SNOWY = "\U000F0598"
ICON_LIGHTNING = "\U000F0593"
ICON_NIGHT = "\U000F0594"

ICON_CODES = {
    1000: ICON_SUNNY,
    1003: ICON_PARTLY,
    1006: ICON_CLOUDY,
    1009: ICON_CLOUDY,
    1012: ICON_FOG,
    1015: ICON_FOG,
    1018: ICON_FOG,
    1021: ICON_FOG,
    1024: ICON_FOG,
    1027: ICON_FOG,
    1030: ICON_FOG,
    1033: ICON_FOG,
    1036: ICON_FOG,
    1039: ICON_FOG,
    1042: ICON_FOG,
    1045: ICON_FOG,
    1048: ICON_FOG,
    1063: ICON_RAINY,
    1066: ICON_SNOWY,
    1069: ICON_RAINY,
    1072: ICON_RAINY,
    1087: ICON_LIGHTNING,
    1114: ICON_SNOWY,
    1117: ICON_SNOWY,
    1150: ICON_RAINY,
    1153: ICON_RAINY,
    1168: ICON_RAINY,
    1171: ICON_RAINY,
    1180: ICON_RAINY,
    1183: ICON_RAINY,
    1186: ICON_RAINY,
    1189: ICON_RAINY,
    1192: ICON_POURING,
    1195: ICON_POURING,
    1198: ICON_RAINY,
    1201: ICON_POURING,
    1204: ICON_SNOWY,
    1207: ICON_SNOWY,
    1210: ICON_SNOWY,
    1213: ICON_SNOWY,
    1216: ICON_SNOWY,
    1219: ICON_SNOWY,
    1222: ICON_SNOWY,
    1225: ICON_SNOWY,
    1237: ICON_SNOWY,
    1240: ICON_RAINY,
    1243: ICON_POURING,
    1246: ICON_POURING,
    1249: ICON_SNOWY,
    1252: ICON_SNOWY,
    1255: ICON_SNOWY,
    1258: ICON_SNOWY,
    1261: ICON_SNOWY,
    1264: ICON_SNOWY,
    1273: ICON_LIGHTNING,
    1276: ICON_LIGHTNING,
    1279: ICON_LIGHTNING,
    1282: ICON_LIGHTNING,
}

APIKEY_ERROR_CODES = {1002, 2006, 2008, 2009}


def city_icon(code, is_day=1):
    if not isinstance(code, int):
        return ICON_CLOUDY
    if is_day == 0 and code in (1000, 1003):
        return ICON_NIGHT
    return ICON_CODES.get(code, ICON_CLOUDY)


def find_city(key):
    for city in CITIES:
        if key in (city["id"], city["name"], city["short"]):
            return city
    return None


def cache_path(city):
    return CACHE_DIR / f"{city['id']}.json"


def load_entry(city):
    try:
        return json.loads(cache_path(city).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def store_entry(city, entry):
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    target = cache_path(city)
    tmp = target.with_suffix(".tmp")
    tmp.write_text(json.dumps(entry, ensure_ascii=False), encoding="utf-8")
    tmp.replace(target)


def entry_ttl(entry):
    if not entry:
        return 0
    if entry.get("ok"):
        return TTL_OK
    return TTL_OK if entry.get("kind") == "apikey" else TTL_FAIL


def entry_age(entry):
    if not entry:
        return 1 << 62
    return time.time() - entry.get("fetched_at", 0)


def is_stale(entry):
    return entry_age(entry) >= entry_ttl(entry)


def active_city():
    try:
        key = (CACHE_DIR / ACTIVE_FILE).read_text(encoding="utf-8").strip()
    except OSError:
        key = DEFAULT_CITY
    return find_city(key) or find_city(DEFAULT_CITY)


def set_active(city):
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    (CACHE_DIR / ACTIVE_FILE).write_text(city["id"] + "\n", encoding="utf-8")


def api_key():
    key = os.environ.get("WEATHERAPI_API_KEY", "").strip()
    if not key or key == PLACEHOLDER_KEY:
        return None
    return key


def classify_error(code):
    if code in APIKEY_ERROR_CODES:
        return "apikey"
    return "api"


def escape_markup(text):
    return (
        str(text or "")
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


def slim_payload(payload):
    current = payload.get("current") or {}
    forecast = payload.get("forecast") or {}
    days = forecast.get("forecastday") or [{}]
    today = days[0] if days else {}
    day_info = today.get("day") or {}
    astro = today.get("astro") or {}
    condition = current.get("condition") or {}
    day_condition = day_info.get("condition") or {}

    def num(value, digits=0):
        if value is None:
            return None
        try:
            return round(float(value), digits) if digits else round(float(value))
        except (TypeError, ValueError):
            return None

    return {
        "temp": num(current.get("temp_c")),
        "feels": num(current.get("feelslike_c")),
        "text": escape_markup(condition.get("text")),
        "code": condition.get("code"),
        "is_day": current.get("is_day"),
        "humidity": num(current.get("humidity")),
        "wind": num(current.get("wind_kph")),
        "precip": num(current.get("precip_mm"), 1),
        "observed": current.get("last_updated") or "",
        "high": num(day_info.get("maxtemp_c")),
        "low": num(day_info.get("mintemp_c")),
        "rain": num(day_info.get("daily_chance_of_rain")),
        "day_text": escape_markup(day_condition.get("text")),
        "sunrise": astro.get("sunrise") or "",
        "sunset": astro.get("sunset") or "",
        "days": slim_days(days),
    }


def slim_days(days):
    rows = []
    for item in days:
        info = item.get("day") or {}
        condition = info.get("condition") or {}
        date_text = item.get("date") or ""
        weekday = ""
        try:
            weekday = WEEKDAYS[date.fromisoformat(date_text).weekday()]
        except ValueError:
            weekday = ""
        rows.append(
            {
                "date": date_text,
                "weekday": weekday,
                "text": escape_markup(condition.get("text")),
                "code": condition.get("code"),
                "high": num_or_none(info.get("maxtemp_c")),
                "low": num_or_none(info.get("mintemp_c")),
                "rain": num_or_none(info.get("daily_chance_of_rain")),
            }
        )
    return rows


def num_or_none(value):
    try:
        return round(float(value))
    except (TypeError, ValueError):
        return None


def request_city(city, key):
    query = urllib.parse.urlencode(
        {
            "key": key,
            "q": f"{city['lat']},{city['lon']}",
            "days": FORECAST_DAYS,
            "aqi": "no",
            "alerts": "no",
            "lang": "zh",
        }
    )
    url = f"{API_URL}?{query}"
    request = urllib.request.Request(url, headers={"User-Agent": "bar-weather/1.0"})
    try:
        with urllib.request.urlopen(request, timeout=HTTP_TIMEOUT) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as err:
        body = b""
        try:
            body = err.read()
        except Exception:
            pass
        code = None
        message = f"HTTP {err.code}"
        try:
            parsed = json.loads(body.decode("utf-8"))
            error = parsed.get("error") or {}
            code = error.get("code")
            message = error.get("message") or message
        except Exception:
            pass
        kind = classify_error(code) if code is not None else "api"
        if err.code in (401, 403):
            kind = "apikey"
        return {"ok": False, "kind": kind, "message": message}
    except Exception:
        return {"ok": False, "kind": "network", "message": "网络不可用"}

    error = payload.get("error")
    if error:
        code = error.get("code")
        return {
            "ok": False,
            "kind": classify_error(code),
            "message": error.get("message") or "接口返回错误",
        }

    return {"ok": True, "data": slim_payload(payload)}


def key_flag_active():
    try:
        stamp = float((CACHE_DIR / KEY_FLAG).read_text(encoding="utf-8").strip())
    except (OSError, ValueError):
        return False
    return time.time() - stamp < TTL_OK


def set_key_flag(active):
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    flag = CACHE_DIR / KEY_FLAG
    try:
        if active:
            flag.write_text(str(int(time.time())), encoding="utf-8")
        elif flag.exists():
            flag.unlink()
    except OSError:
        pass


def fetch_entry(city, key):
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    try:
        handle = open(CACHE_DIR / f"{city['id']}.lock", "w")
    except OSError:
        return None
    with handle:
        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            return None
        try:
            return request_city(city, key)
        finally:
            fcntl.flock(handle, fcntl.LOCK_UN)


def ensure_cities(cities, key):
    if key is not None and key_flag_active():
        return {
            city["id"]: {"ok": False, "kind": "apikey", "message": "API key 无效"}
            for city in cities
        }
    entries = {}
    stale = []
    for city in cities:
        entry = load_entry(city)
        entries[city["id"]] = entry
        if key is not None and is_stale(entry):
            stale.append(city)
    if not stale:
        return entries
    with ThreadPoolExecutor(max_workers=len(stale)) as pool:
        tasks = [(city, pool.submit(fetch_entry, city, key)) for city in stale]
        for city, task in tasks:
            fresh = task.result()
            if fresh is None:
                continue
            fresh["fetched_at"] = time.time()
            store_entry(city, fresh)
            entries[city["id"]] = fresh
    results = [entries.get(city["id"]) or {} for city in stale]
    if any(entry.get("kind") == "apikey" for entry in results):
        set_key_flag(True)
    elif any(entry.get("ok") for entry in results):
        set_key_flag(False)
    return entries


def ensure_city(city, key):
    return ensure_cities([city], key)[city["id"]]


def error_text(entry):
    kind = (entry or {}).get("kind") or "pending"
    if kind == "apikey":
        return "APIKEY ERR"
    if kind == "network":
        return "NO NET"
    if kind == "pending":
        return "LOADING"
    return "API ERR"


def bar_text(city, entry, key):
    if key is None:
        return f"{ICON_CLOUDY} PLS CFG APIKEY"
    if entry and entry.get("ok"):
        data = entry["data"]
        icon = city_icon(data.get("code"), data.get("is_day"))
        return f"{icon} {city['short']} {data.get('temp')}°C"
    return f"{ICON_CLOUDY} {error_text(entry)}"


def bar_class(entry, key):
    if key is None:
        return "unset"
    if entry and entry.get("ok"):
        return "ok"
    if (entry or {}).get("kind") == "apikey":
        return "error"
    return "warn"


def forecast_lines(entry):
    rows = ((entry or {}).get("data") or {}).get("days") or []
    lines = []
    for row in rows:
        icon = city_icon(row.get("code"))
        lines.append(
            f"{row.get('date', '')[5:]} {row.get('weekday', '')} {icon} "
            f"{row.get('text', '')} {row.get('low')}~{row.get('high')}°C "
            f"降水{row.get('rain')}%"
        )
    return lines


def updated_text(entry):
    stamp = (entry or {}).get("fetched_at")
    if not stamp:
        return "更新 --:--"
    return time.strftime("%m-%d %H:%M", time.localtime(stamp))


def city_detail(city, entry, key):
    lines = [city["name"]]
    if key is None:
        lines.append("未配置 WEATHERAPI_API_KEY")
        lines.append("请在 sensitive_env.nix 中填写后重新部署")
        return lines
    if entry and entry.get("ok"):
        data = entry["data"]
        lines.append(f"{data.get('temp')}°C {data.get('text')} 体感 {data.get('feels')}°C")
        if data.get("high") is not None and data.get("low") is not None:
            lines.append(
                f"最高 {data.get('high')}°C 最低 {data.get('low')}°C 降水 {data.get('rain')}%"
            )
        lines.append(f"湿度 {data.get('humidity')}% 风 {data.get('wind')}km/h")
        lines.extend(forecast_lines(entry))
        lines.append(updated_text(entry))
        return lines
    if (entry or {}).get("kind") == "apikey":
        lines.append("API key 无效或已禁用")
        if entry.get("message"):
            lines.append(entry["message"])
    elif (entry or {}).get("kind") == "network":
        lines.append("无网络连接，无法更新天气")
    elif entry is None or entry.get("kind") == "pending":
        lines.append("正在获取天气数据")
    else:
        lines.append("天气接口返回错误")
        if (entry or {}).get("message"):
            lines.append(entry["message"])
    lines.append(updated_text(entry))
    return lines


def refresh_bar():
    for name, command in (
        ("waybar", ["pkill", "-SIGUSR2", "-x", "waybar"]),
        ("ironbar", ["ironbar", "reload"]),
    ):
        try:
            if subprocess.run(["pgrep", "-x", name], capture_output=True).returncode != 0:
                continue
            subprocess.run(command, capture_output=True, timeout=5)
        except (OSError, subprocess.SubprocessError):
            pass


POPUP_BG = "#1c1f21"
POPUP_PANEL = "#26292b"
POPUP_FG = "#e3e8e2"
POPUP_ACCENT = "#7fd0c8"
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


def popup_window(title, width, height):
    import tkinter as tk

    root = tk.Tk()
    root.title(title)
    root.configure(bg=POPUP_BG)
    root.attributes("-type", "dialog")
    root.resizable(False, False)
    screen_w, screen_h = root.winfo_screenwidth(), root.winfo_screenheight()
    root.geometry(
        f"{width}x{height}+{(screen_w - width) // 2}+{(screen_h - height) // 3}"
    )
    root.attributes("-topmost", True)
    root.bind("<Escape>", lambda _event: root.destroy())
    return root


def popup_button(parent, text, command):
    import tkinter as tk

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
        padx=14,
        pady=6,
        font=(POPUP_FONT, 11),
        cursor="hand2",
    )


def switch_city(city_id):
    for city in CITIES:
        if city["id"] == city_id:
            set_active(city)
            refresh_bar()
            return True
    return False


def run_picker():
    active_id = active_city()["id"]
    if not popup_ready():
        print("\n".join(f"{city['name']}" for city in CITIES))
        return
    lock = popup_lock(PICKER_LOCK)
    if lock is None:
        return
    import tkinter as tk

    root = popup_window("选择默认城市", 320, 320)
    frame = tk.Frame(root, bg=POPUP_BG)
    frame.pack(fill="both", expand=True, padx=12, pady=12)
    tk.Label(
        frame,
        text="双击或选中后确定，设为 bar 显示的默认城市",
        bg=POPUP_BG,
        fg=POPUP_FG,
        anchor="w",
        justify="left",
        wraplength=260,
        font=(POPUP_FONT, 10),
    ).pack(fill="x", pady=(0, 8))
    listing = tk.Listbox(
        frame,
        bg=POPUP_PANEL,
        fg=POPUP_FG,
        selectbackground=POPUP_ACCENT,
        selectforeground=POPUP_BG,
        relief="flat",
        bd=0,
        highlightthickness=0,
        activestyle="none",
        font=(POPUP_FONT, 12),
    )
    for city in CITIES:
        listing.insert("end", city["name"])
    ids = [city["id"] for city in CITIES]
    if active_id in ids:
        listing.selection_set(ids.index(active_id))
        listing.see(ids.index(active_id))
    listing.pack(fill="both", expand=True)

    def confirm(_event=None):
        selection = listing.curselection()
        if selection:
            switch_city(ids[selection[0]])
        root.destroy()

    buttons = tk.Frame(frame, bg=POPUP_BG)
    buttons.pack(fill="x", pady=(10, 0))
    popup_button(buttons, "确定", confirm).pack(side="right")
    popup_button(buttons, "取消", root.destroy).pack(side="right", padx=(0, 8))
    listing.bind("<Double-Button-1>", confirm)
    listing.bind("<Return>", confirm)
    root.bind("<Return>", confirm)
    listing.focus_set()
    root.mainloop()
    lock.close()


def detail_lines(entries, key):
    lines = []
    for index, city in enumerate(CITIES):
        if index:
            lines.append("")
        entry = entries.get(city["id"])
        mark = "●" if city["id"] == active_city()["id"] else "○"
        block = city_detail(city, entry, key)
        block[0] = f"{mark} {block[0]}"
        lines.extend(block)
    return lines


def run_detail(key):
    entries = ensure_cities(CITIES, key)
    text = plain_text("\n".join(detail_lines(entries, key)))
    if not popup_ready():
        print(text)
        return
    lock = popup_lock(DETAIL_LOCK)
    if lock is None:
        return
    import tkinter as tk

    root = popup_window("天气预报", 820, 560)
    frame = tk.Frame(root, bg=POPUP_BG)
    frame.pack(fill="both", expand=True, padx=12, pady=12)
    body = tk.Text(
        frame,
        bg=POPUP_PANEL,
        fg=POPUP_FG,
        relief="flat",
        bd=0,
        highlightthickness=0,
        padx=12,
        pady=10,
        wrap="none",
        font=(POPUP_FONT, 11),
        cursor="arrow",
    )
    body.insert("1.0", text)
    body.configure(state="disabled")

    def reload():
        body.configure(state="normal")
        body.delete("1.0", "end")
        body.insert("1.0", plain_text("\n".join(detail_lines(ensure_cities(CITIES, key), key))))
        body.configure(state="disabled")
    scroll = tk.Scrollbar(frame, command=body.yview, width=10)
    body.configure(yscrollcommand=scroll.set)
    scroll.pack(side="right", fill="y")
    body.pack(side="left", fill="both", expand=True)
    buttons = tk.Frame(root, bg=POPUP_BG)
    buttons.pack(fill="x", padx=12, pady=(0, 12))
    popup_button(buttons, "切换默认城市", run_picker).pack(side="left")
    popup_button(buttons, "刷新", reload).pack(side="left", padx=(8, 0))
    popup_button(buttons, "关闭", root.destroy).pack(side="right")
    root.mainloop()
    lock.close()


def all_summary(key):
    active_id = active_city()["id"]
    entries = ensure_cities(CITIES, key)
    lines = []
    for city in CITIES:
        entry = entries.get(city["id"])
        mark = "●" if city["id"] == active_id else "○"
        if entry and entry.get("ok"):
            data = entry["data"]
            icon = city_icon(data.get("code"), data.get("is_day"))
            lines.append(
                f"{mark} {icon} {city['name']}  {data.get('temp')}°C {data.get('text')}  "
                f"{data.get('low')}~{data.get('high')}°  降水{data.get('rain')}%  "
                f"{updated_text(entry)}"
            )
        else:
            lines.append(f"{mark} {ICON_CLOUDY} {city['name']}  {error_text(entry)}")
    return "\n".join(lines)


def all_blocks(key):
    return "\n".join(detail_lines(ensure_cities(CITIES, key), key))


def city_status_text(city, key):
    entry = ensure_city(city, key)
    return bar_text(city, entry, key)


def print_waybar(key):
    city = active_city()
    entries = ensure_cities(CITIES, key)
    entry = entries.get(city["id"])
    text = bar_text(city, entry, key)
    if key is not None and entry and entry.get("ok"):
        icon, rest = text.split(" ", 1)
        text = f"<span font='16'>{icon}</span> {rest}"
    payload = {
        "text": text,
        "tooltip": all_summary(key),
        "class": bar_class(entry, key),
    }
    print(json.dumps(payload, ensure_ascii=False))


def main():
    args = sys.argv[1:]
    key = api_key()

    if not args or args[0] == "--text":
        city = active_city()
        print(city_status_text(city, key))
        return
    if args[0] == "--waybar":
        print_waybar(key)
        return
    if args[0] == "--tooltip":
        print(all_summary(key))
        return
    if args[0] == "--picker":
        run_picker()
        return
    if args[0] == "--detail":
        run_detail(key)
        return
    if args[0] == "--forecast-all":
        print(all_blocks(key))
        return
    if args[0] in ("--next", "--prev"):
        index = CITIES.index(active_city())
        step = 1 if args[0] == "--next" else -1
        city = CITIES[(index + step) % len(CITIES)]
        set_active(city)
        print(city_status_text(city, key))
        refresh_bar()
        return
    if args[0] == "--set-city":
        city = find_city(args[1]) if len(args) > 1 else None
        if city is None:
            sys.exit(f"unknown city: {args[1] if len(args) > 1 else ''}")
        set_active(city)
        print(city_status_text(city, key))
        return
    sys.exit(f"unknown option: {args[0]}")


if __name__ == "__main__":
    main()
