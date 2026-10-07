extends GutTest
## 日历 / 时钟的纯算术单测。

var _clock: Clock


func before_each() -> void:
	_clock = Clock.new()


func test_defaults() -> void:
	assert_eq(_clock.year, 1, "第一年")
	assert_eq(_clock.season, Clock.SPRING, "从春天开始")
	assert_eq(_clock.day, 1, "从 1 号开始")
	assert_eq(_clock.minute_of_day, Clock.DAY_START_MINUTE, "06:00 起床")


func test_tick_minute_returns_crossed_hour() -> void:
	_clock.minute_of_day = 6 * 60 + 59
	assert_eq(_clock.tick_minute(), 7, "跨过 07:00 时应返回 7")
	assert_eq(_clock.hour(), 7)
	assert_eq(_clock.minute(), 0)


func test_tick_minute_within_hour_returns_minus_one() -> void:
	_clock.minute_of_day = 6 * 60 + 10
	assert_eq(_clock.tick_minute(), -1, "没跨整点返回 -1")


func test_midnight_wraps_to_zero() -> void:
	_clock.minute_of_day = Clock.MINUTES_PER_DAY - 1
	assert_eq(_clock.tick_minute(), 0, "23:59 → 00:00 应返回 0")
	assert_eq(_clock.minute_of_day, 0)


func test_season_changes_after_28_days() -> void:
	_clock.day = Clock.DAYS_PER_SEASON
	var result: Dictionary = _clock.advance_to_next_day()
	assert_eq(_clock.day, 1, "跨季后回到 1 号")
	assert_eq(_clock.season, Clock.SUMMER, "春 → 夏")
	assert_eq(_clock.year, 1, "还没跨年")
	assert_true(VariantUtil.dict_bool(result, "season_changed"))
	assert_false(VariantUtil.dict_bool(result, "year_changed"))


func test_year_changes_after_winter() -> void:
	_clock.season = Clock.WINTER
	_clock.day = Clock.DAYS_PER_SEASON
	var result: Dictionary = _clock.advance_to_next_day()
	assert_eq(_clock.season, Clock.SPRING, "冬 → 春")
	assert_eq(_clock.year, 2, "跨年")
	assert_true(VariantUtil.dict_bool(result, "year_changed"))


func test_advance_resets_to_morning() -> void:
	_clock.minute_of_day = 60
	_clock.advance_to_next_day()
	assert_eq(_clock.minute_of_day, Clock.DAY_START_MINUTE, "跨天后回到 06:00 起床时间")


func test_season_names() -> void:
	assert_eq(_clock.season_name(), "春")
	_clock.season = Clock.WINTER
	assert_eq(_clock.season_name(), "冬")


func test_is_night() -> void:
	_clock.minute_of_day = 12 * 60
	assert_false(_clock.is_night(), "中午不是夜晚")
	_clock.minute_of_day = 8 * 60
	assert_false(_clock.is_night(), "早上 8 点不是夜晚")
	_clock.minute_of_day = 20 * 60
	assert_true(_clock.is_night(), "20:00 是夜晚")
	_clock.minute_of_day = 60
	assert_true(_clock.is_night(), "凌晨 1:00 是夜晚")


func test_day_of_year() -> void:
	_clock.season = Clock.SUMMER
	_clock.day = 1
	assert_eq(_clock.day_of_year(), 29, "夏 1 日 = 一年中第 29 天")


func test_serialize_round_trip() -> void:
	_clock.year = 3
	_clock.season = Clock.FALL
	_clock.day = 17
	_clock.minute_of_day = 14 * 60 + 30

	var restored: Clock = Clock.from_dict(_clock.to_dict())
	assert_eq(restored.year, 3)
	assert_eq(restored.season, Clock.FALL)
	assert_eq(restored.day, 17)
	assert_eq(restored.minute_of_day, 14 * 60 + 30)


func test_from_dict_tolerates_missing_fields() -> void:
	var restored: Clock = Clock.from_dict({})
	assert_eq(restored.year, 1)
	assert_eq(restored.season, Clock.SPRING)
	assert_eq(restored.day, 1)
	assert_eq(restored.minute_of_day, Clock.DAY_START_MINUTE)
