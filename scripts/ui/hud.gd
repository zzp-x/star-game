class_name Hud
extends CanvasLayer
## M0 调试用 HUD —— 全部 UI 在代码里构建，不依赖任何 .tscn 子节点或美术资源。
##
## 【层级】L4 表现层
## 【为什么 M0 不做得更漂亮】UI 皮肤属于 M2。现在只需要一眼看清
##   「时间 / 天气 / 体力 / 钱 / 鼠标指向的格子」，用来验证玩法循环是否跑通。

const MARGIN: float = 18.0
const TOAST_SECONDS: float = 2.0

var _info_label: Label
var _hint_label: Label
var _toast_label: Label

var _toast_timer: float = 0.0
var _farm_view: FarmView = null


func _ready() -> void:
	layer = 10
	_build_ui()

	EventBus.toast.connect(_on_toast)
	EventBus.day_changed.connect(_on_day_changed)


func _process(delta: float) -> void:
	_refresh_info()

	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast_label.text = ""


# ── 构建 UI ──────────────────────────────────────────────

func _build_ui() -> void:
	_info_label = _make_label(Vector2(MARGIN, MARGIN), 18, Color(1, 1, 1, 0.94))
	_info_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	_info_label.add_theme_constant_override("shadow_offset_x", 1)
	_info_label.add_theme_constant_override("shadow_offset_y", 1)

	_hint_label = _make_label(Vector2(MARGIN, MARGIN + 108.0), 14, Color(1, 1, 1, 0.72))
	_hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	_hint_label.add_theme_constant_override("shadow_offset_x", 1)
	_hint_label.add_theme_constant_override("shadow_offset_y", 1)

	# 底部居中提示条
	_toast_label = Label.new()
	_toast_label.anchor_left = 0.5
	_toast_label.anchor_right = 0.5
	_toast_label.anchor_top = 1.0
	_toast_label.anchor_bottom = 1.0
	_toast_label.offset_left = -260.0
	_toast_label.offset_right = 260.0
	_toast_label.offset_top = -70.0
	_toast_label.offset_bottom = -34.0
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 22)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.8))
	_toast_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_toast_label.add_theme_constant_override("shadow_offset_x", 2)
	_toast_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_toast_label)


func _make_label(pos: Vector2, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


# ── 刷新 ─────────────────────────────────────────────────

func _refresh_info() -> void:
	var clock: Clock = TimeManager.clock
	var night_tag: String = "（夜间）" if TimeManager.is_night() else ""

	_info_label.text = "第 %d 年 · %s %d 日  %02d:%02d\n天气 %s%s\n体力 %d / %d      金币 %d G" % [
		clock.year,
		clock.season_name(),
		clock.day,
		clock.hour(),
		clock.minute(),
		TimeManager.weather_name(),
		night_tag,
		GameManager.stamina,
		GameManager.MAX_STAMINA,
		GameManager.money,
	]

	var crop: CropData = GameManager.selected_crop()
	var crop_text: String = "无" if crop == null else "%s（%d 天成熟 · 售价 %d G）" % [
		crop.display_name, crop.mature_days, crop.sell_price,
	]

	if _farm_view == null:
		_farm_view = get_tree().get_first_node_in_group("farm_view") as FarmView

	var hover_text: String = "—"
	if _farm_view != null and _farm_view.hovered_cell() != FarmView.NO_CELL:
		hover_text = GameManager.describe(_farm_view.hovered_cell())

	_hint_label.text = "当前种子：%s\n指向格：%s\n\nWASD 移动 · Shift 跑 · 左键操作 · Q/E 转视角 · 滚轮缩放 · 1-5 换种子 · F10 过夜 · F9 存档 · F5 读档" % [
		crop_text,
		hover_text,
	]


## 调试快捷键：F5 存档 / F9 读档（正式版会换成菜单，这里只为验证存档链路）
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return

	match key.physical_keycode:
		KEY_F5:
			SaveManager.save_game(1)
			get_viewport().set_input_as_handled()
		KEY_F9:
			if SaveManager.load_game(1):
				var view: FarmView = get_tree().get_first_node_in_group("farm_view") as FarmView
				if view != null:
					view.refresh_all()
			get_viewport().set_input_as_handled()


func _on_toast(text: String) -> void:
	_toast_label.text = text
	_toast_timer = TOAST_SECONDS


func _on_day_changed(_day: int, _season: int) -> void:
	_toast_label.text = "新的一天：%s" % TimeManager.weather_name()
	_toast_timer = TOAST_SECONDS
