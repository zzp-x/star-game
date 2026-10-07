class_name HudHotbar
extends Control
## 底部快捷栏（星露谷的 12 格工具栏）：前 3 格是工具，后 9 格是种子。
##
## 【层级】L4 表现层
## 【为什么直接在 _draw 里画，而不是挂 12 个格子节点】
##   12 个格子 + 12 个图标 = 24 个节点，只为画静态内容。
##   一次 _draw 更轻，也不用操心容器的布局与鼠标穿透。
## 【为什么非当季的种子要变灰】种错季节会白白浪费一天。
##   让玩家在"选种子"这一步就看出能不能种，比种下去才弹提示友好得多。
## 【为什么工具格要用另一种底色】玩家需要一眼分出"左边三格是家伙什、
##   右边是种子"。只靠图标形状区分的话，缩放到 4K 或小窗口时就开始靠猜了。
## 【为什么顶部要写手持物名称】M0.5 起"手上拿什么"直接决定"能做什么"，
##   所以它必须比一个高亮框更显眼 —— 高亮框只说明"第几格"，
##   名字才说明"我现在能干什么"。

const SLOT_SIZE: float = 60.0
const SLOT_GAP: float = 5.0
## 选中框往外扩多少（星露谷的选中格是"浮起来"的）
const SELECT_GROW: float = 4.0
## 格子区相对木条内沿再留一点，避免选中框贴着木框
const INNER_PAD: float = SELECT_GROW + 2.0
## 木条自身的厚度
const PANEL_PAD: float = 10.0
const ICON_RATIO: float = 0.62
## 木条顶部留给"手持物名称"的高度
const LABEL_BAND: float = 36.0

## 12 格的按键标签。顺序 = 格位顺序，与 GameManager.TOOL_ACTIONS 一一对应。
##
## 【为什么末尾是 0 - =】数字键只有 1~9，装不下 12 格。
##   星露谷用的就是 0 / - / =，玩家的肌肉记忆里有这套。
const KEY_LABELS: Array[String] = [
	"1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=",
]

var _entries: Array[HotbarEntry] = []
var _last_signature: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entries = GameManager.hotbar.entries()
	custom_minimum_size = Vector2(
		_slots_width() + (INNER_PAD + PANEL_PAD) * 2.0,
		LABEL_BAND + SLOT_SIZE + (INNER_PAD + PANEL_PAD) * 2.0,
	)
	EventBus.slot_selected.connect(_on_slot_selected)
	queue_redraw()


func _process(_delta: float) -> void:
	# 季节影响"非当季种子变灰"，选中格影响高亮 —— 两者或布局一变才重画
	var signature: String = "%d|%d|%d" % [
		TimeManager.clock.season, GameManager.selected_slot, _entries.size(),
	]
	if signature != _last_signature:
		_last_signature = signature
		queue_redraw()


func _on_slot_selected(_slot: int) -> void:
	queue_redraw()


func _slots_width() -> float:
	var count: int = _entries.size()
	if count <= 0:
		return 0.0
	return float(count) * SLOT_SIZE + float(count - 1) * SLOT_GAP


func _slots_origin() -> Vector2:
	return Vector2(INNER_PAD + PANEL_PAD, INNER_PAD + PANEL_PAD + LABEL_BAND)


func _draw() -> void:
	# 整条木质底衬
	draw_style_box(UiTheme.panel_style(), Rect2(Vector2.ZERO, size))
	_draw_hand_label()

	var season: int = TimeManager.clock.season
	var selected: int = GameManager.selected_slot
	var origin: Vector2 = _slots_origin()

	for i: int in _entries.size():
		var entry: HotbarEntry = _entries[i]
		var rect: Rect2 = Rect2(
			origin + Vector2(float(i) * (SLOT_SIZE + SLOT_GAP), 0.0),
			Vector2(SLOT_SIZE, SLOT_SIZE),
		)

		if i == selected:
			draw_style_box(UiTheme.slot_selected_style(), rect.grow(SELECT_GROW))
		elif entry.is_empty():
			draw_style_box(UiTheme.slot_empty_style(), rect)
		elif entry.is_tool():
			draw_style_box(UiTheme.slot_tool_style(), rect)
		else:
			draw_style_box(UiTheme.slot_style(), rect)

		if entry.is_empty():
			continue

		# 只有种子会"因为季节不对而变灰"；工具和季节无关
		var faded: bool = entry.is_seed() and not entry.grows_in_season(season)

		# 工具走工具图标表，种子走作物图标
		var icon_kind: int = UiIcon.Kind.CROP
		if entry.is_tool():
			icon_kind = UiIcon.kind_for_tool(entry.id)
		if icon_kind < 0:
			icon_kind = UiIcon.Kind.CROP

		UiIcon.draw_shape(
			self,
			icon_kind,
			rect.get_center() + Vector2(0.0, 3.0),
			SLOT_SIZE * ICON_RATIO,
			entry.color,
			faded,
		)
		if i < KEY_LABELS.size():
			_draw_key_label(KEY_LABELS[i], rect.position + Vector2(4.0, 15.0), faded)


## 把手持物名字写在木条顶部 —— 是"我现在能做什么"的唯一权威提示。
func _draw_hand_label() -> void:
	var entry: HotbarEntry = GameManager.selected_entry()
	var text: String = "空手" if entry == null or entry.is_empty() else entry.label

	var font: Font = ThemeDB.fallback_font
	var font_size: int = 21
	var width: float = font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
	).x
	var at: Vector2 = Vector2((size.x - width) * 0.5, PANEL_PAD + LABEL_BAND * 0.70)

	draw_string_outline(
		font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4,
		Color(0.14, 0.07, 0.02, 0.90),
	)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1.0, 0.96, 0.86))

	# 名称与格子之间一道浅分隔线，让"上面是名字、下面是格子"读起来是一体的
	var y: float = PANEL_PAD + LABEL_BAND - 7.0
	draw_line(
		Vector2(PANEL_PAD + 6.0, y),
		Vector2(size.x - PANEL_PAD - 6.0, y),
		Color(0.30, 0.18, 0.08, 0.45),
		2.0,
	)


## 格子左上角的按键提示（1…9、0、-、=）。
func _draw_key_label(text: String, at: Vector2, faded: bool) -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = 13
	var color: Color = Color(0.90, 0.86, 0.78, 0.55) if faded else Color(1.0, 0.97, 0.88, 0.92)
	draw_string_outline(
		font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3,
		Color(0.12, 0.06, 0.02, 0.85),
	)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
