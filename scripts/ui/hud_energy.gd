class_name HudEnergy
extends Control
## 体力条 —— 竖直，放在屏幕右下角（与星露谷一致）。
##
## 【层级】L4 表现层
## 【为什么用竖直条而不是数字】体力是"看一眼还剩多少"的资源，
##   长度是最快的编码方式；数字要读，反而慢。
##   颜色再补一层信息：绿=充裕，黄=该回家了，红=快没力气了。
## 【为什么不显示具体数值】星露谷也不显示。想核对具体数字可以按 F1 看帮助面板。

const BAR_WIDTH: float = 30.0
const BAR_HEIGHT: float = 140.0
## 外框里再留的边距
const FRAME: float = 6.0

var _last_ratio: float = -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 外框样式带落影，给右下各让一点绘制空间（不影响布局锚点）
	custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	queue_redraw()


func _process(_delta: float) -> void:
	var ratio: float = _ratio()
	# 只在"看得出来的变化"时重画，避免每帧重绘（体力有 270 档，不必逐档重画）
	if absf(ratio - _last_ratio) > 0.004:
		_last_ratio = ratio
		queue_redraw()


func _ratio() -> float:
	if GameManager.MAX_STAMINA <= 0:
		return 0.0
	return clampf(float(GameManager.stamina) / float(GameManager.MAX_STAMINA), 0.0, 1.0)


func _draw() -> void:
	var ratio: float = _ratio()

	# 厚木外框（向外扩一圈，包住内条）
	var outer: Rect2 = Rect2(Vector2.ZERO, Vector2(BAR_WIDTH, BAR_HEIGHT)).grow(6.0)
	draw_style_box(UiTheme.frame_style(), outer)

	var inner: Rect2 = Rect2(Vector2.ZERO, Vector2(BAR_WIDTH, BAR_HEIGHT)).grow(-FRAME)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return

	# 空槽：先铺满深色，再往上盖填充 —— 这样"还剩多少"一眼可见
	draw_rect(inner, Color(0.20, 0.13, 0.07, 1.0))

	var fill_height: float = inner.size.y * ratio
	if fill_height > 0.5:
		var fill: Rect2 = Rect2(
			Vector2(inner.position.x, inner.position.y + inner.size.y - fill_height),
			Vector2(inner.size.x, fill_height),
		)
		var color: Color = UiTheme.energy_color(ratio)
		draw_rect(fill, color)
		# 左侧一条高光，让条子有点体积感
		draw_rect(
			Rect2(fill.position + Vector2(2.0, 1.0), Vector2(4.0, maxf(0.0, fill.size.y - 2.0))),
			Color(1.0, 1.0, 1.0, 0.25),
		)

	# 分段刻度：每 25% 一道 —— 帮玩家估算"还够干几件事"
	for i: int in range(1, 4):
		var y: float = inner.position.y + inner.size.y * float(i) / 4.0
		draw_line(
			Vector2(inner.position.x, y),
			Vector2(inner.position.x + inner.size.x, y),
			Color(0.0, 0.0, 0.0, 0.30),
			1.0,
		)
