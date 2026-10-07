class_name Clock
extends RefCounted
## 游戏日历 + 时钟的纯算术部分。
##
## 【层级】L2 领域逻辑 —— 零节点依赖，可在 GUT 中直接单测（见 test/unit/test_clock.gd）。
## 【纪律】本类只做算术，不广播信号、不碰场景。推进与广播是 L3 TimeManager 的职责。

enum Season {
	SPRING = 0,
	SUMMER = 1,
	FALL = 2,
	WINTER = 3,
}

const SPRING: int = Season.SPRING
const SUMMER: int = Season.SUMMER
const FALL: int = Season.FALL
const WINTER: int = Season.WINTER

const SEASON_NAMES: Array[String] = ["春", "夏", "秋", "冬"]

const DAYS_PER_SEASON: int = 28
const SEASONS_PER_YEAR: int = 4
const MINUTES_PER_HOUR: int = 60
const HOURS_PER_DAY: int = 24
const MINUTES_PER_DAY: int = MINUTES_PER_HOUR * HOURS_PER_DAY

## 每天 06:00 起床。
const DAY_START_MINUTE: int = 6 * 60
## 次日 02:00 强制昏睡。
const DAY_FORCE_SLEEP_MINUTE: int = 2 * 60
## 夜晚起点 18:00（光照转冷、变暗，见 DESIGN.md §3.4）。
const NIGHT_START_MINUTE: int = 18 * 60

var year: int = 1
var season: int = Season.SPRING
var day: int = 1
var minute_of_day: int = DAY_START_MINUTE


func _init(p_year: int = 1, p_season: int = Season.SPRING, p_day: int = 1) -> void:
	year = p_year
	season = p_season
	day = p_day


# ── 查询 ────────────────────────────────────────────────

func hour() -> int:
	return minute_of_day / MINUTES_PER_HOUR


func minute() -> int:
	return minute_of_day % MINUTES_PER_HOUR


func season_name() -> String:
	return SEASON_NAMES[season]


func is_night() -> bool:
	return minute_of_day >= NIGHT_START_MINUTE or minute_of_day < DAY_FORCE_SLEEP_MINUTE


## 一年中的第几天（1..112），便于季节视觉与统计。
func day_of_year() -> int:
	return season * DAYS_PER_SEASON + day


# ── 推进 ────────────────────────────────────────────────

## 推进一分钟。返回本次跨过的整点（0-23）；未跨整点则返回 -1。
## 跨日**不在这里发生** —— 请由 TimeManager 调用 advance_to_next_day()。
func tick_minute() -> int:
	var previous_hour: int = hour()
	minute_of_day += 1
	if minute_of_day >= MINUTES_PER_DAY:
		minute_of_day = 0
	var current_hour: int = hour()
	if current_hour != previous_hour:
		return current_hour
	return -1


## 进入次日并重置到起床时间。
## 返回 {"season_changed": bool, "year_changed": bool}，供 TimeManager 决定广播哪些信号。
func advance_to_next_day() -> Dictionary:
	day += 1
	var season_changed: bool = false
	var year_changed: bool = false
	if day > DAYS_PER_SEASON:
		day = 1
		season += 1
		season_changed = true
		if season >= SEASONS_PER_YEAR:
			season = 0
			year += 1
			year_changed = true
	minute_of_day = DAY_START_MINUTE
	return {"season_changed": season_changed, "year_changed": year_changed}


# ── 序列化 ──────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"year": year,
		"season": season,
		"day": day,
		"minute_of_day": minute_of_day,
	}


static func from_dict(data: Dictionary) -> Clock:
	var clock: Clock = Clock.new()
	clock.year = VariantUtil.dict_int(data, "year", 1)
	clock.season = VariantUtil.dict_int(data, "season", Season.SPRING)
	clock.day = VariantUtil.dict_int(data, "day", 1)
	clock.minute_of_day = VariantUtil.dict_int(data, "minute_of_day", DAY_START_MINUTE)
	return clock


func format() -> String:
	return "%s %d 日  %02d:%02d" % [season_name(), day, hour(), minute()]
