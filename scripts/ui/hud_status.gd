class_name HudStatus
extends VBoxContainer
## 右上角状态面板（星露谷布局）：日期 → 时间 + 天气 → 金钱。
##
## 【层级】L4 表现层 —— 只读游戏状态，不写。
## 【为什么分三个独立面板而不是一块大的】星露谷就是这么做的：
##   三块小面板各自独立，信息层级一眼分明，也方便以后单独替换。
## 【为什么中间是"时间 + 天气"合在一块】天气决定了今天要不要浇水，
##   把它和时间放一起看最顺手。

const PANEL_WIDTH: float = 190.0

var _season_icon: UiIcon
var _date_label: Label
var _year_label: Label
var _weather_icon: UiIcon
var _time_label: Label
var _period_label: Label
var _gold_label: Label

## 缓存上一次显示的内容，避免每帧重设文本导致重排
var _last_signature: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 8)
	_build()
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _build() -> void:
	# ① 日期：季节图标 + "春 3 日" + "第 1 年"
	var date_row: HBoxContainer = _row(10)
	_season_icon = UiIcon.make(UiIcon.Kind.SEASON, UiTheme.SEASON_COLORS[0], 30.0)
	date_row.add_child(_season_icon)

	var date_text: VBoxContainer = VBoxContainer.new()
	date_text.add_theme_constant_override("separation", -2)
	date_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_date_label = UiTheme.make_label("春 1 日", UiTheme.FONT_TITLE, UiTheme.TEXT_DARK)
	date_text.add_child(_date_label)
	_year_label = UiTheme.make_label("第 1 年", UiTheme.FONT_SMALL, UiTheme.TEXT_MUTED, 3)
	date_text.add_child(_year_label)
	date_row.add_child(date_text)
	add_child(_wrap(date_row))

	# ② 时间 + 天气
	var time_row: HBoxContainer = _row(9)
	_weather_icon = UiIcon.make(UiIcon.Kind.SUNNY, Color.WHITE, 28.0)
	time_row.add_child(_weather_icon)
	_time_label = UiTheme.make_label("6:00", UiTheme.FONT_TITLE, UiTheme.TEXT_DARK)
	time_row.add_child(_time_label)
	_period_label = UiTheme.make_label("上午", UiTheme.FONT_SMALL, UiTheme.TEXT_MUTED, 3)
	_period_label.size_flags_vertical = Control.SIZE_SHRINK_END
	time_row.add_child(_period_label)
	add_child(_wrap(time_row))

	# ③ 金钱：金币图标 + 数字（右对齐）+ 单位
	var gold_row: HBoxContainer = _row(8)
	gold_row.add_child(UiIcon.make(UiIcon.Kind.COIN, Color.WHITE, 26.0))
	_gold_label = UiTheme.make_label("0", UiTheme.FONT_TITLE, UiTheme.GOLD)
	_gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gold_row.add_child(_gold_label)
	gold_row.add_child(UiTheme.make_label("G", UiTheme.FONT_SMALL, UiTheme.TEXT_MUTED, 3))
	add_child(_wrap(gold_row))


## 面板统一宽度 + 右对齐（SHRINK_END 让它在 VBox 里靠右，不会被拉满屏宽）
func _wrap(content: HBoxContainer) -> PanelContainer:
	var panel: PanelContainer = UiTheme.make_panel()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	return panel


func _row(separation: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", separation)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row


# ── 刷新 ─────────────────────────────────────────────────

func _refresh() -> void:
	var clock: Clock = TimeManager.clock
	var hour: int = clock.hour()
	var minute: int = clock.minute()

	# 拼一个"当前显示内容"的指纹：内容没变就整帧不动，省掉重排
	var signature: String = "%d|%d|%d|%d|%d|%d" % [
		clock.year, clock.season, clock.day, hour, minute, GameManager.money,
	]
	signature += "|%d" % TimeManager.weather
	if signature == _last_signature:
		return
	_last_signature = signature

	_season_icon.kind = UiIcon.Kind.SEASON
	_season_icon.tint = UiTheme.SEASON_COLORS[clock.season]
	_date_label.text = "%s %d 日" % [clock.season_name(), clock.day]
	_year_label.text = "第 %d 年" % clock.year

	_weather_icon.kind = UiIcon.kind_for_weather(TimeManager.weather)
	_time_label.text = _format_time(hour, minute)
	_period_label.text = _period_name(hour)

	_gold_label.text = str(GameManager.money)


## 星露谷用的是 12 小时制。"晚上 11:30" 比 "23:30" 更有生活感。
func _format_time(hour: int, minute: int) -> String:
	var h12: int = hour % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d" % [h12, minute]


func _period_name(hour: int) -> String:
	if hour < 5:
		return "凌晨"
	if hour < 12:
		return "上午"
	if hour < 18:
		return "下午"
	return "晚上"
