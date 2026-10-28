#!/usr/bin/env python3
import tempfile
from datetime import date, datetime
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
BASE_DATE = date(1900, 1, 31)
WEEKDAYS = ("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
CACHE_DIR = Path(tempfile.gettempdir()) / "bar-lunar"


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


def main():
    now = datetime.now()
    today = now.date()
    print(
        f"{WEEKDAYS[today.weekday()]} {today.isoformat()} "
        f"{cached_lunar_text(today)} {now.strftime('%H:%M')}"
    )


if __name__ == "__main__":
    main()
