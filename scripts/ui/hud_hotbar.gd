class_name HudHotbar
extends Control
## 底部快捷栏（星露谷的 12 格工具栏）。
##
## 【层级】L4 表现层
## 【为什么直接在 _draw 里画，而不是挂 12 个格子节点】
##   12 个格子 + 12 个图标 = 24 个节点，只为画静态内容。
##   一次 _draw 更轻，也不用操心容器的布局与鼠标穿透。
## 【为什么非当季的种子要变灰】种错季节会白白浪费一天。
##   让玩家在"选种子"这一步就看出能不能种，比种下去才弹提示友好得多。

const SLOT_COUNT: int = 12
const SLOT_SIZE: float = 60.0
const SLOT_GAP: float = 5.0
## 选中框往外扩多少（星露谷的选中格是"浮起来"的）
const SELECT_GROW: float = 4.0
## 格子区相对木条内沿再留一点，避免选中框贴着木框
const INNER_PAD: float = SELECT_GROW + 2.0
## 木条自身的厚度
const PANEL_PAD: float = 10.0
const ICON_RATIO: float = 0.62

var _crops: Array[CropData] = []
var _last_signature: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for id: String in CropDatabase.all_ids():
		var crop: CropData = CropDatabase.get_crop(id)
		if crop != null:
			_crops.append(crop)
	custom_minimum_size = Vector2(_slots_width() + (INNER_PAD + PANEL_PAD) * 2.0, SLOT_SIZE + (INNER_PAD + PANEL_PAD) * 2.0)
	queue_redraw()


func _process(_delta: float) -> void:
	var signature: String = "%d|%s" % [TimeManager.clock.season, GameManager.selected_crop_id]
	if signature != _last_signature:
		_last_signature = signature
		queue_redraw()


func _slots_width() -> float:
	return float(SLOT_COUNT) * SLOT_SIZE + float(SLOT_COUNT - 1) * SLOT_GAP


func _slots_origin() -> Vector2:
	return Vector2(INNER_PAD + PANEL_PAD, INNER_PAD + PANEL_PAD)


func _draw() -> void:
	# 整条木质底衬
	draw_style_box(UiTheme.panel_style(), Rect2(Vector2.ZERO, size))

	var season: int = TimeManager.clock.season
	var selected_id: String = GameManager.selected_crop_id
	var origin: Vector2 = _slots_origin()

	for i: int in SLOT_COUNT:
		var rect: Rect2 = Rect2(
			origin + Vector2(float(i) * (SLOT_SIZE + SLOT_GAP), 0.0),
			Vector2(SLOT_SIZE, SLOT_SIZE),
		)
		var crop: CropData = _crops[i] if i < _crops.size() else null
		var is_selected: bool = crop != null and crop.id == selected_id

		if is_selected:
			draw_style_box(UiTheme.slot_selected_style(), rect.grow(SELECT_GROW))
		elif crop == null:
			draw_style_box(UiTheme.slot_empty_style(), rect)
		else:
			draw_style_box(UiTheme.slot_style(), rect)

		if crop == null:
			continue

		var faded: bool = not crop.grows_in_season(season)
		UiIcon.draw_shape(
			self,
			UiIcon.Kind.CROP,
			rect.get_center() + Vector2(0.0, 3.0),
			SLOT_SIZE * ICON_RATIO,
			crop.icon_color,
			faded,
		)
		_draw_index(i + 1, rect.position + Vector2(4.0, 15.0), faded)


## 格子左上角的小数字 —— 对应键盘 1~9。
func _draw_index(number: int, at: Vector2, faded: bool) -> void:
	if number > 9:
		return
	var font: Font = ThemeDB.fallback_font
	var text: String = str(number)
	var font_size: int = 13
	var color: Color = Color(0.90, 0.86, 0.78, 0.55) if faded else Color(1.0, 0.97, 0.88, 0.92)
	draw_string_outline(
		font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3,
		Color(0.12, 0.06, 0.02, 0.85),
	)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
