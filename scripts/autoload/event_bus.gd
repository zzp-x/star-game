extends Node
## 全局事件总线。
##
## 【层级】L3 单例（Autoload）
## 【纪律 · 最重要的一条】只放「跨场景」的信号。
##   同一场景树内部的通信请用局部 `signal`，不要往这里塞。
##   口诀：「能局部就局部，跨场景才上 EventBus」（见 DESIGN.md §4.4）
##
## 【为什么需要它】时间系统永远不需要知道游戏里有多少系统。
##   TimeManager 只负责「推进 + 广播」，作物 / 光照 / UI 各自订阅自己响应。
##
## ⚠️ 不要给本文件加 `class_name` —— Autoload 单例名与 class_name 同名会冲突。

# ── 时间 ─────────────────────────────────────────────────

## 每游戏分钟
signal minute_tick(total_minutes: int)
## 整点（0-23）
signal hour_changed(hour: int)
## ★ 一天结束（在日历推进**之前**发射）。
##   携带的是「刚刚结束这一天」的日期与天气 —— 作物每日生长挂这里。
##   ⚠️ 不要改用 day_changed 驱动作物生长：day_changed 发射时天气已经重掷成新一天的，
##      会导致"明天要下雨"变成"今天就长"（这个 bug 由集成测试抓出来过）。
signal day_ended(day: int, season: int, weather: int)
## 跨天（睡觉后，日历已推进、新一天天气已掷出）
signal day_changed(day: int, season: int)
## 跨季
signal season_changed(season: int)
## 跨年
signal year_changed(year: int)
## 天气重掷（每天清晨）
signal weather_rolled(weather: int)

# ── 农场 ─────────────────────────────────────────────────

## 翻地成功
signal land_tilled(cell: Vector2i)
## 浇水成功
signal crop_watered(cell: Vector2i)
## 播种成功
signal crop_planted(cell: Vector2i, crop_id: String)
## 收获成功
signal crop_harvested(cell: Vector2i, crop_id: String, amount: int)
## 某格状态发生任何变化，表现层可据此做增量刷新（最省事的兜底信号）
signal tile_changed(cell: Vector2i)

# ── 玩家 ─────────────────────────────────────────────────

signal money_changed(amount: int)
signal stamina_changed(current: int, maximum: int)
## 玩家换了手持格位（按数字键 / 滚轮）。UI 据此刷新快捷栏高亮与手持物标签。
##
## 【为什么是"格位下标"而不是"作物 id"】手上有可能是工具，不一定是种子。
##   发下标是唯一能同时表达"第几格"和"手上是什么"的形式；
##   想知道具体是什么，调用方去 `GameManager.selected_entry()` 取。
signal slot_selected(slot: int)

# ── 存档 ─────────────────────────────────────────────────

signal game_saved(slot: int)
signal game_loaded(slot: int)

# ── 界面（UI） ───────────────────────────────────────────────────

## 屏幕提示（"翻地""播种 芜菁""体力不足"…）
signal toast(text: String)
## 玩家按了 F10 强制过夜 / 执行了一次调试操作
signal debug_message(text: String)


## 调试辅助：打印当前所有连接数，排查「信号泄漏」时很有用。
func debug_connection_counts() -> Dictionary:
	return {
		"minute_tick": get_signal_connection_list("minute_tick").size(),
		"day_changed": get_signal_connection_list("day_changed").size(),
		"tile_changed": get_signal_connection_list("tile_changed").size(),
	}
