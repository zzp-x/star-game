extends Node
## 游戏时间推进器 —— 全项目唯一的「进入次日」入口。
##
## 【层级】L3 单例（Autoload）
## 【纪律 · 核心】只负责「推进 + 广播」，**绝不**直接去改作物、商店、光照。
##   作物、光照、UI 各自订阅 EventBus 信号自己响应。
##   这样时间系统永远不需要知道游戏里有多少个系统（见 DESIGN.md §3.4）。
##
## 【信号发射顺序 · 不要改】一次 sleep() 的顺序是：
##   advance_to_next_day() → weather_rolled → day_changed → season_changed? → year_changed?
##   天气必须先于 day_changed 掷出，否则 GameManager 拿不到「今天下没下雨」。
##
## ⚠️ 不要给本文件加 `class_name` —— 与 Autoload 单例名冲突。

## 1 游戏分钟 = 0.7 真实秒（见 DESIGN.md §3.10）。
## 一天 06:00 → 次日 02:00 共 1200 游戏分钟 ≈ 14 真实分钟。
@export var real_seconds_per_game_minute: float = 0.7
@export var auto_advance: bool = true

## 日历（纯逻辑，L2）
var clock: Clock = Clock.new()
## 今天的天气，取值见 Weather.Kind
var weather: int = Weather.SUNNY
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _minute_accumulator: float = 0.0


func _ready() -> void:
	rng.randomize()
	weather = Weather.roll(clock.season, rng)
	# 暂停时仍需响应输入，所以不跟随场景树的暂停状态
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if not auto_advance:
		return
	var seconds_per_minute: float = maxf(real_seconds_per_game_minute, 0.001)
	_minute_accumulator += delta / seconds_per_minute
	while _minute_accumulator >= 1.0:
		_minute_accumulator -= 1.0
		advance_one_minute()


# ── 推进 ─────────────────────────────────────────────────

## 推进一分钟并广播。跨整点时发 hour_changed；到 02:00 强制昏睡。
func advance_one_minute() -> void:
	var crossed_hour: int = clock.tick_minute()
	EventBus.minute_tick.emit(clock.minute_of_day)
	if crossed_hour >= 0:
		EventBus.hour_changed.emit(crossed_hour)
	if clock.minute_of_day == Clock.DAY_FORCE_SLEEP_MINUTE:
		sleep()


## 进入次日。这是全项目唯一的跨天入口 —— 睡觉、F10 调试、床铺都走这里。
##
## 【发射顺序 · 不要改】day_ended(旧日期, 旧天气) → 日历推进 → 掷新天气
##   → weather_rolled → day_changed → season_changed? → year_changed?
##
##   ⚠️ day_ended 必须在日历推进**之前**发射，且携带**旧天气**。
##      作物生长判断的是"今天下没下雨"，而不是"明天会不会下雨"。
func sleep() -> void:
	EventBus.day_ended.emit(clock.day, clock.season, weather)

	var result: Dictionary = clock.advance_to_next_day()
	_minute_accumulator = 0.0

	weather = Weather.roll(clock.season, rng)
	EventBus.weather_rolled.emit(weather)

	EventBus.day_changed.emit(clock.day, clock.season)

	if VariantUtil.dict_bool(result, "season_changed", false):
		EventBus.season_changed.emit(clock.season)
	if VariantUtil.dict_bool(result, "year_changed", false):
		EventBus.year_changed.emit(clock.year)


# ── 查询 ─────────────────────────────────────────────────

func is_night() -> bool:
	return clock.is_night()


## 供 HUD / 太阳控制器使用的归一化时间：0.0 = 起床(06:00)，1.0 = 极限(次日02:00)。
## 注意跨零点：18:00 之后 minute_of_day 会绕回 0，这里统一映射到 0.6~1.0。
func normalized_day_progress() -> float:
	var minute: int = clock.minute_of_day
	var shifted: int = minute - Clock.DAY_START_MINUTE
	if shifted < 0:
		shifted += Clock.MINUTES_PER_DAY
	var total: int = 20 * Clock.MINUTES_PER_HOUR
	return clampf(float(shifted) / float(total), 0.0, 1.0)


func time_string() -> String:
	return clock.format()


func weather_name() -> String:
	return Weather.name_of(weather)


# ── 存档 ─────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"clock": clock.to_dict(),
		"weather": weather,
	}


func from_dict(data: Dictionary) -> void:
	clock = Clock.from_dict(VariantUtil.dict_dict(data, "clock"))
	weather = VariantUtil.dict_int(data, "weather", Weather.SUNNY)
	_minute_accumulator = 0.0
