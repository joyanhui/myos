#!/usr/bin/env python3
import fcntl
import json
import os
import sys
import tempfile
import time
from datetime import date, datetime, timedelta
from pathlib import Path

LUNAR_INFO = [
    0x04BD8, 0x04AE0, 0x0A570, 0x054D5, 0x0D260, 0x0D950, 0x16554, 0x056A0, 0x09AD0, 0x055D2,
    0x04AE0, 0x0A5B6, 0x0A4D0, 0x0D250, 0x1D255, 0x0B540, 0x0D6A0, 0x0ADA2, 0x095B0, 0x14977,
    0x04970, 0x0A4B0, 0x0B4B5, 0x06A50, 0x06D40, 0x1AB54, 0x02B60, 0x09570, 0x052F2, 0x04970,
    0x06566, 0x0D4A0, 0x0EA50, 0x06E95, 0x05AD0, 0x02B60, 0x186E3, 0x092E0, 0x1C8D7, 0x0C950,
    0x0D4A0, 0x1D8A6, 0x0B550, 0x056A0, 0x1A5B4, 0x025D0, 0x092D0, 0x0D2B2, 0x0A950, 0x0B557,
    0x06CA0, 0x0B550, 0x15355, 0x04DA0, 0x0A5B0, 0x14573, 0x052B0, 0x0A9A8, 0x0E950, 0x06AA0,
    0x0AEA6, 0x0AB50, 0x04B60, 0x0AAE4, 0x0A570, 0x05260, 0x0F263, 0x0D950, 0x05B57, 0x056A0,
    0x096D0, 0x04DD5, 0x04AD0, 0x0A4D0, 0x0D4D4, 0x0D250, 0x0D558, 0x0B540, 0x0B6A0, 0x195A6,
    0x095B0, 0x049B0, 0x0A974, 0x0A4B0, 0x0B27A, 0x06A50, 0x06D40, 0x0AF46, 0x0AB60, 0x09570,
    0x04AF5, 0x04970, 0x064B0, 0x074A3, 0x0EA50, 0x06B58, 0x05AC0, 0x0AB60, 0x096D5, 0x092E0,
    0x0C960, 0x0D954, 0x0D4A0, 0x0DA50, 0x07552, 0x056A0, 0x0ABB7, 0x025D0, 0x092D0, 0x0CAB5,
    0x0A950, 0x0B4A0, 0x0BAA4, 0x0AD50, 0x055D9, 0x04BA0, 0x0A5B0, 0x15176, 0x052B0, 0x0A930,
    0x07954, 0x06AA0, 0x0AD50, 0x05B52, 0x04B60, 0x0A6E6, 0x0A4E0, 0x0D260, 0x0EA65, 0x0D530,
    0x05AA0, 0x076A3, 0x096D0, 0x04AFB, 0x04AD0, 0x0A4D0, 0x1D0B6, 0x0D250, 0x0D520, 0x0DD45,
    0x0B5A0, 0x056D0, 0x055B2, 0x049B0, 0x0A577, 0x0A4B0, 0x0AA50, 0x1B255, 0x06D20, 0x0ADA0,
    0x14B63, 0x09370, 0x049F8, 0x04970, 0x064B0, 0x168A6, 0x0EA50, 0x06B20, 0x1A6C4, 0x0AAE0,
    0x092E0, 0x0D2E3, 0x0C960, 0x0D557, 0x0D4A0, 0x0DA50, 0x05D55, 0x056A0, 0x0A6D0, 0x055D4,
    0x052D0, 0x0A9B8, 0x0A950, 0x0B4A0, 0x0B6A6, 0x0AD50, 0x055A0, 0x0ABA4, 0x0A5B0, 0x052B0,
    0x0B273, 0x06930, 0x07337, 0x06AA0, 0x0AD50, 0x14B55, 0x04B60, 0x0A570, 0x054E4, 0x0D160,
    0x0E968, 0x0D520, 0x0DAA0, 0x16AA6, 0x056D0, 0x04AE0, 0x0A9D4, 0x0A2D0, 0x0D150, 0x0F252,
    0x0D520,
]

MONTH_NAMES = ["正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"]
DAY_TENS = ["初", "十", "廿", "三"]
DAY_UNITS = ["十", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
GANZHI_STEMS = ("甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸")
GANZHI_BRANCHES = ("子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥")
ZODIACS = ("鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪")
BASE_DATE = date(1900, 1, 31)
WEEKDAYS = ("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
WEEKDAY_LABELS = ("一", "二", "三", "四", "五", "六", "日")
CACHE_DIR = Path(tempfile.gettempdir()) / "bar-lunar"
DETAIL_LOCK = "detail.lock"
MIN_LUNAR_YEAR = 1900
MAX_LUNAR_YEAR = 2100


def leap_month(year):
    return LUNAR_INFO[year - 1900] & 0xF


def leap_days(year):
    if leap_month(year):
        return 30 if LUNAR_INFO[year - 1900] & 0x10000 else 29
    return 0


def month_days(year, month):
    return 30 if LUNAR_INFO[year - 1900] & (0x10000 >> month) else 29


def year_days(year):
    total = 29 * 12
    for month in range(1, 13):
        if LUNAR_INFO[year - 1900] & (0x10000 >> month):
            total += 1
    return total + leap_days(year)


def solar_to_lunar(day):
    offset = (day - BASE_DATE).days
    year = 1900
    while year < 2101 and offset >= year_days(year):
        offset -= year_days(year)
        year += 1
    leap = leap_month(year)
    month = 1
    is_leap = False
    while True:
        days = leap_days(year) if is_leap else month_days(year, month)
        if offset < days:
            break
        offset -= days
        if leap and month == leap and not is_leap:
            is_leap = True
        else:
            is_leap = False
            month += 1
    return year, month, offset + 1, is_leap


def lunar_month_name(month, is_leap):
    return ("闰" if is_leap else "") + MONTH_NAMES[month - 1] + "月"


def lunar_day_name(day):
    if day == 10:
        return "初十"
    if day == 20:
        return "二十"
    if day == 30:
        return "三十"
    return DAY_TENS[day // 10] + DAY_UNITS[day % 10]


def lunar_text(today):
    year, month, day, is_leap = solar_to_lunar(today)
    return lunar_month_name(month, is_leap) + lunar_day_name(day)


def lunar_year_days(year):
    return year_days(year)


def year_leap(year):
    return leap_month(year) != 0


def lunar_to_solar(year, month, day, is_leap=False):
    if not MIN_LUNAR_YEAR <= year <= MAX_LUNAR_YEAR:
        raise ValueError(f"year out of range: {year}")
    offset = sum(year_days(item) for item in range(MIN_LUNAR_YEAR, year))
    leap = leap_month(year)
    for index in range(1, month):
        offset += month_days(year, index)
        if leap == index:
            offset += leap_days(year)
    if is_leap:
        if leap != month:
            raise ValueError(f"year {year} month {month} has no leap month")
        offset += month_days(year, month)
    if not 1 <= day <= (leap_days(year) if is_leap else month_days(year, month)):
        raise ValueError(f"invalid lunar day: {day}")
    return BASE_DATE + timedelta(days=offset + day - 1)


def lunar_months_of_year(year):
    leap = leap_month(year)
    months = []
    for month in range(1, 13):
        months.append((month, False))
        if leap == month:
            months.append((month, True))
    return months


def ganzhi_year(year):
    return GANZHI_STEMS[(year - 4) % 10] + GANZHI_BRANCHES[(year - 4) % 12]


def zodiac_of(year):
    return ZODIACS[(year - 4) % 12]


def solar_month_grid(year, month):
    first = date(year, month, 1)
    next_month = date(year + (month == 12), 1 if month == 12 else month + 1, 1)
    lead = first.weekday()
    days = (next_month - first).days
    cells = [None] * lead
    for day in range(1, days + 1):
        cells.append(first + timedelta(days=day - 1))
    cells.extend([None] * ((7 - len(cells) % 7) % 7))
    return cells


def cached_lunar_text(today):
    cache_file = CACHE_DIR / today.isoformat()
    try:
        text = cache_file.read_text(encoding="utf-8").strip()
        if text:
            return text
    except OSError:
        pass
    text = lunar_text(today)
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        for stale in CACHE_DIR.iterdir():
            if stale.name != today.isoformat():
                stale.unlink()
        cache_file.write_text(text + "\n", encoding="utf-8")
    except OSError:
        pass
    return text


POPUP_BG = "#121619"
POPUP_PANEL = "#1b2226"
POPUP_TODAY = "#22302f"
POPUP_FG = "#e3e8e2"
POPUP_DIM = "#8b9a93"
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


def month_cell_text(day):
    year, month, lunar_day, is_leap = solar_to_lunar(day)
    if lunar_day == 1:
        return lunar_month_name(month, is_leap)
    return lunar_day_name(lunar_day)


def month_title(year, month):
    lunar_year, _, _, _ = solar_to_lunar(date(year, month, 15))
    return f"{year} 年 {month} 月   {ganzhi_year(lunar_year)}年 {zodiac_of(lunar_year)}"


def run_calendar():
    today = date.today()
    if not popup_ready():
        print(month_title(today.year, today.month))
        for cell in solar_month_grid(today.year, today.month):
            if cell is None:
                continue
            print(f"{cell.day:2d} {month_cell_text(cell)}")
        return
    lock = popup_lock(DETAIL_LOCK)
    if lock is None:
        return
    import tkinter as tk

    root = tk.Tk()
    root.title("农历万年历")
    root.configure(bg=POPUP_BG)
    root.resizable(False, False)
    width, height = 900, 820
    screen_w, screen_h = root.winfo_screenwidth(), root.winfo_screenheight()
    root.geometry(
        f"{width}x{height}+{(screen_w - width) // 2}+{max(0, (screen_h - height) // 3)}"
    )
    root.attributes("-topmost", True)
    root.bind("<Escape>", lambda _event: root.destroy())

    state = {"year": today.year, "month": today.month}

    header = tk.Frame(root, bg=POPUP_BG)
    header.pack(fill="x", padx=18, pady=(16, 8))
    title = tk.Label(
        header,
        bg=POPUP_BG,
        fg=POPUP_FG,
        font=(POPUP_FONT, 17, "bold"),
    )
    title.pack(side="left")

    def button(parent, text, command, font_size=14, padx=16, pady=8):
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
            padx=padx,
            pady=pady,
            font=(POPUP_FONT, font_size),
            cursor="hand2",
        )

    controls = tk.Frame(header, bg=POPUP_BG)
    controls.pack(side="right")

    grid = tk.Frame(root, bg=POPUP_BG)
    grid.pack(fill="both", expand=True, padx=18, pady=(0, 8))
    footer = tk.Frame(root, bg=POPUP_BG)
    footer.pack(fill="x", padx=18, pady=(0, 14))
    footer_text = tk.Label(
        footer,
        bg=POPUP_BG,
        fg=POPUP_DIM,
        anchor="w",
        justify="left",
        font=(POPUP_FONT, 13),
    )
    footer_text.pack(side="left")
    clock = tk.Label(
        footer,
        bg=POPUP_BG,
        fg=POPUP_ACCENT,
        font=(POPUP_FONT, 13),
    )
    clock.pack(side="right")

    def tick():
        clock.configure(text=datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
        root.after(1000, tick)

    def step(delta):
        month = state["month"] + delta
        year = state["year"]
        while month < 1:
            month += 12
            year -= 1
        while month > 12:
            month -= 12
            year += 1
        if MIN_LUNAR_YEAR <= year <= MAX_LUNAR_YEAR:
            state["year"] = year
            state["month"] = month
            render()

    def step_year(delta):
        year = state["year"] + delta
        if MIN_LUNAR_YEAR <= year <= MAX_LUNAR_YEAR:
            state["year"] = year
            render()

    def go_today():
        state["year"] = today.year
        state["month"] = today.month
        render()

    def describe(day):
        lunar_year, month, lunar_day, is_leap = solar_to_lunar(day)
        label = (
            f"公历 {day.isoformat()} 星期{WEEKDAY_LABELS[day.weekday()]}   "
            f"农历 {ganzhi_year(lunar_year)}年 {lunar_month_name(month, is_leap)}"
            f"{lunar_day_name(lunar_day)}"
        )
        leap_year = "闰年" if year_leap(lunar_year) else "平年"
        footer_text.configure(text=f"{label}   农历{leap_year}，{lunar_year_days(lunar_year)} 天")

    def render():
        for child in grid.winfo_children():
            child.destroy()
        year, month = state["year"], state["month"]
        title.configure(text=month_title(year, month))
        for column, name in enumerate(WEEKDAY_LABELS):
            tk.Label(
                grid,
                text=name,
                bg=POPUP_BG,
                fg=POPUP_ACCENT if column >= 5 else POPUP_DIM,
                font=(POPUP_FONT, 14, "bold"),
                width=6,
            ).grid(row=0, column=column, pady=(0, 6))
        for index, day in enumerate(solar_month_grid(year, month)):
            row, column = divmod(index, 7)
            row += 1
            if day is None:
                tk.Label(grid, text="", bg=POPUP_BG, width=6, height=2).grid(
                    row=row, column=column, padx=2, pady=2
                )
                continue
            cell = tk.Frame(
                grid,
                bg=POPUP_TODAY if day == today else POPUP_PANEL,
                width=96,
                height=72,
            )
            cell.grid(row=row, column=column, padx=2, pady=2, sticky="nsew")
            cell.grid_propagate(False)
            number = tk.Label(
                cell,
                text=str(day.day),
                bg=cell["bg"],
                fg=POPUP_ACCENT if day == today else POPUP_FG,
                font=(POPUP_FONT, 16, "bold"),
            )
            number.pack(pady=(6, 0))
            sub = tk.Label(
                cell,
                text=month_cell_text(day),
                bg=cell["bg"],
                fg=POPUP_DIM,
                font=(POPUP_FONT, 11),
            )
            sub.pack()
            for widget in (cell, number, sub):
                widget.bind("<Button-1>", lambda _event, d=day: describe(d))

    button(controls, "上年", lambda: step_year(-1)).pack(side="left", padx=3)
    button(controls, "上月", lambda: step(-1)).pack(side="left", padx=3)
    button(controls, "今天", go_today).pack(side="left", padx=3)
    button(controls, "下月", lambda: step(1)).pack(side="left", padx=3)
    button(controls, "下年", lambda: step_year(1)).pack(side="left", padx=3)
    button(controls, "关闭", root.destroy).pack(side="left", padx=(14, 0))

    root.bind("<Left>", lambda _event: step(-1))
    root.bind("<Right>", lambda _event: step(1))
    root.bind("<Prior>", lambda _event: step_year(-1))
    root.bind("<Next>", lambda _event: step_year(1))

    render()
    describe(today)
    tick()
    root.mainloop()
    lock.close()


def main():
    args = sys.argv[1:]
    now = datetime.now()
    today = now.date()
    if args and args[0] == "--ashell-listen":
        while True:
            now = datetime.now()
            today = now.date()
            print(
                json.dumps(
                    {"text": cached_lunar_text(today), "alt": "lunar"},
                    ensure_ascii=False,
                ),
                flush=True,
            )
            time.sleep(max(1, 60 - now.second))
        return
    if args and args[0] in ("--waybar", "--noctalia"):
        print(
            json.dumps(
                {
                    "text": cached_lunar_text(today),
                    "tooltip": (
                        f"农历 {ganzhi_year(today.year)}年（{zodiac_of(today.year)}）  "
                        "点击打开万年历"
                    ),
                    "class": "ok",
                },
                ensure_ascii=False,
            )
        )
        return
    if args and args[0] == "--calendar":
        run_calendar()
        return
    print(cached_lunar_text(today))


if __name__ == "__main__":
    main()
