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
##
## 【名称牌为什么悬挑在木条外】星露谷切换物品时，物品名是一块**压在
##   工具栏上沿的小木牌**，而不是"工具栏内部留一行"。
##   悬挑的好处：① 木条可以更薄，格子可以更大；② 名牌出现的位置
##   在视线焦点（格子）的正上方，扫一眼就到；③ 不切物品时名牌
##   视觉上属于"格子区"，不会像内嵌文字那样显得像标题栏。

const SLOT_SIZE: float = 66.0
const SLOT_GAP: float = 7.0
## 选中框往外扩多少（星露谷的选中格是"浮起来"的）
const SELECT_GROW: float = 5.0
## 格子区相对木条内沿再留一点，避免选中框贴着木框
const INNER_PAD: float = SELECT_GROW + 3.0
## 木条自身的厚度
const PANEL_PAD: float = 12.0
const ICON_RATIO: float = 0.64
## 悬挑名称牌的尺寸与下探深度（下探 = 压进木条上沿多少）
const NAMEPLATE_HEIGHT: float = 44.0
const NAMEPLATE_DROP: float = 18.0
## 名称牌左右留白
const NAMEPLATE_PAD: float = 26.0

## 12 格的按键标签。顺序 = 格位顺序，与 GameManager.TOOL_ACTIONS 一一对应。
##
## 【为什么末尾是 0 - =】数字键只有 1~9，装不下 12 格。
##   星露谷用的就是 0 / - / =，玩家的肌肉记忆里有这套。
const KEY_LABELS: Array[String] = [
	"1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "=",
]
## 工具占用前几格（与 GameManager/Hotbar 的布局约定一致）
const TOOL_SLOTS: int = 3

var _entries: Array[HotbarEntry] = []
var _last_signature: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entries = GameManager.hotbar.entries()
	custom_minimum_size = Vector2(
		_slots_width() + (INNER_PAD + PANEL_PAD) * 2.0,
		SLOT_SIZE + (INNER_PAD + PANEL_PAD) * 2.0,
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
	return Vector2(INNER_PAD + PANEL_PAD, INNER_PAD + PANEL_PAD)


func _slot_rect(i: int) -> Rect2:
	return Rect2(
		_slots_origin() + Vector2(float(i) * (SLOT_SIZE + SLOT_GAP), 0.0),
		Vector2(SLOT_SIZE, SLOT_SIZE),
	)


func _draw() -> void:
	# 整条木质底衬
	draw_style_box(UiTheme.panel_style(), Rect2(Vector2.ZERO, size))

	var season: int = TimeManager.clock.season
	var selected: int = GameManager.selected_slot

	# 工具区与种子区之间一道浅浅的分隔刻线 —— 不打断木条，但暗示"这是两组东西"
	if _entries.size() > TOOL_SLOTS:
		var edge: float = _slot_rect(TOOL_SLOTS - 1).end.x + SLOT_GAP * 0.5
		draw_line(
			Vector2(edge, INNER_PAD + 6.0),
			Vector2(edge, size.y - INNER_PAD - 6.0),
			Color(0.30, 0.16, 0.06, 0.40),
			2.0,
		)

	# 【两遍绘制】先画所有未选中的格子，最后画选中的 ——
	#   选中格的金色辉光是往外扩的，若按顺序画会被右侧邻居盖掉一半。
	for pass_selected: bool in [false, true]:
		for i: int in _entries.size():
			if (i == selected) != pass_selected:
				continue
			var entry: HotbarEntry = _entries[i]
			var rect: Rect2 = _slot_rect(i)

			if i == selected:
				draw_style_box(
					UiTheme.slot_selected_style(), rect.grow(SELECT_GROW - 1.0),
				)
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
				rect.get_center() + Vector2(0.0, 2.0),
				SLOT_SIZE * ICON_RATIO,
				entry.color,
				faded,
			)
			if i < KEY_LABELS.size():
				_draw_key_badge(KEY_LABELS[i], rect.position, faded)

	_draw_nameplate()


## 悬挑在木条上沿的名称牌 —— "我现在拿的是什么、能干什么"的权威提示。
func _draw_nameplate() -> void:
	var entry: HotbarEntry = GameManager.selected_entry()
	var text: String = "空手" if entry == null or entry.is_empty() else entry.label

	var font: Font = ThemeDB.fallback_font
	var font_size: int = 22
	var text_width: float = font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
	).x

	var plate_width: float = maxf(text_width + NAMEPLATE_PAD * 2.0, 150.0)
	var plate_rect := Rect2(
		Vector2((size.x - plate_width) * 0.5, -(NAMEPLATE_HEIGHT - NAMEPLATE_DROP)),
		Vector2(plate_width, NAMEPLATE_HEIGHT),
	)
	draw_style_box(UiTheme.panel_style(), plate_rect)

	var text_size: Vector2 = font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
	)
	var at: Vector2 = Vector2(
		(size.x - text_width) * 0.5,
		plate_rect.position.y + (NAMEPLATE_HEIGHT + text_size.y * 0.62) * 0.5,
	)
	draw_string_outline(
		font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4,
		Color(0.14, 0.07, 0.02, 0.90),
	)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.99, 0.94, 0.80))


## 格子左上角的圆形按键徽章（1…9、0、-、=）。
##
## 【为什么做成小圆牌而不是裸文字】裸数字浮在图标旁边很容易被当成
##   画面杂物；一枚压暗的圆底小徽章读起来是"这是个按键"，语义清楚。
func _draw_key_badge(text: String, slot_at: Vector2, faded: bool) -> void:
	var center: Vector2 = slot_at + Vector2(13.0, 13.0)
	var radius: float = 10.0
	draw_circle(center, radius + 1.5, Color(0.16, 0.08, 0.03, 0.85))
	draw_circle(center, radius, Color(0.99, 0.92, 0.75, 1.0) if not faded else Color(0.80, 0.74, 0.64, 1.0))

	var font: Font = ThemeDB.fallback_font
	var font_size: int = 13
	var text_size: Vector2 = font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
	)
	var at: Vector2 = center - Vector2(text_size.x * 0.5, -text_size.y * 0.36)
	draw_string(
		font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
		Color(0.30, 0.16, 0.06, 0.95),
	)
