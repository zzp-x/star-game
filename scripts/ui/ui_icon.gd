class_name UiIcon
extends Control
## 程序化绘制的图标（零外部素材）。
##
## 【层级】L4 表现层
## 【为什么用 _draw 而不是贴图】图标形状简单、尺寸多变。
##   矢量绘制省掉一堆 png，还能随 UI 缩放保持清晰 —— 这正是程序化素材的长处。
##
## 【两种用法】
##   ① 当节点用：`UiIcon.make(UiIcon.Kind.COIN, Color.WHITE, 24)` 然后 add_child
##   ② 直接画到别的控件上：`UiIcon.draw_shape(canvas, kind, center, size, tint)`
##      （快捷栏就是直接在 _draw 里画 12 个格子，不再挂 12 个节点）
##
## 【约定】所有形状都按「边长 size 的正方形」设计，中心在 center。
##   这样同一个图标在任何尺寸下比例都一致。

enum Kind {
	CROP,    ## 一株带果实的作物，tint = 品种代表色
	COIN,    ## 金币
	SUNNY,
	RAIN,
	STORM,
	SNOW,
	FOG,
	SEASON,  ## 一片叶子，tint = 季节色
}

var kind: int = Kind.CROP:
	set(value):
		kind = value
		queue_redraw()

## 主色（作物品种色 / 季节色等）
var tint: Color = Color.WHITE:
	set(value):
		tint = value
		queue_redraw()

## 变灰变淡 —— 用来表示"当季不能种"这类无效状态
var faded: bool = false:
	set(value):
		faded = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var box: float = minf(size.x, size.y)
	if box <= 1.0:
		box = custom_minimum_size.x
	draw_shape(self, kind, size * 0.5, box, tint, faded)


static func make(icon_kind: int, icon_tint: Color, box: float) -> UiIcon:
	var icon: UiIcon = UiIcon.new()
	icon.kind = icon_kind
	icon.tint = icon_tint
	icon.custom_minimum_size = Vector2(box, box)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## 按天气类型取图标种类。
static func kind_for_weather(weather: int) -> int:
	match weather:
		Weather.RAIN:
			return Kind.RAIN
		Weather.STORM:
			return Kind.STORM
		Weather.SNOW:
			return Kind.SNOW
		Weather.FOG:
			return Kind.FOG
	return Kind.SUNNY


# ── 分发 ─────────────────────────────────────────────────

static func draw_shape(
	canvas: CanvasItem,
	icon_kind: int,
	center: Vector2,
	box: float,
	tint: Color,
	faded: bool = false,
) -> void:
	var color: Color = tint
	var alpha: float = 1.0
	if faded:
		# 去饱和 + 压暗，而不是简单地把透明度调低 —— 后者会让图标"消失"
		var gray: float = color.get_luminance()
		color = Color(gray, gray, gray).lerp(color, 0.25)
		alpha = 0.65

	match icon_kind:
		Kind.CROP:
			_draw_crop(canvas, center, box, color, alpha)
		Kind.COIN:
			_draw_coin(canvas, center, box, alpha)
		Kind.SUNNY:
			_draw_sunny(canvas, center, box, alpha)
		Kind.RAIN:
			_draw_rain(canvas, center, box, alpha, false)
		Kind.STORM:
			_draw_rain(canvas, center, box, alpha, true)
		Kind.SNOW:
			_draw_snow(canvas, center, box, alpha)
		Kind.FOG:
			_draw_fog(canvas, center, box, alpha)
		Kind.SEASON:
			_draw_leaf(canvas, center, box, color, alpha)


# ── 各图标 ───────────────────────────────────────────────

## 一株小苗：茎 + 两片叶 + 一颗果实。果实颜色就是品种色。
static func _draw_crop(canvas: CanvasItem, c: Vector2, box: float, tint: Color, alpha: float) -> void:
	var stem: Color = Color(0.30, 0.55, 0.24, alpha)
	var leaf: Color = Color(0.38, 0.68, 0.30, alpha)

	canvas.draw_line(
		Vector2(c.x, c.y + box * 0.42),
		Vector2(c.x, c.y - box * 0.02),
		stem,
		maxf(1.5, box * 0.075),
	)

	_draw_ellipse(canvas, Vector2(c.x - box * 0.17, c.y + box * 0.10), box * 0.15, 0.5, -0.5, leaf)
	_draw_ellipse(canvas, Vector2(c.x + box * 0.17, c.y + box * 0.10), box * 0.15, 0.5, 0.5, leaf)

	# 果实：先深色描边再填色，小尺寸下也能看清轮廓
	var fruit_c: Vector2 = Vector2(c.x, c.y - box * 0.16)
	canvas.draw_circle(fruit_c, box * 0.27, Color(tint.darkened(0.45), alpha))
	canvas.draw_circle(fruit_c, box * 0.22, Color(tint, alpha))
	# 左上高光
	canvas.draw_circle(
		fruit_c + Vector2(-box * 0.07, -box * 0.08),
		box * 0.07,
		Color(1.0, 1.0, 1.0, alpha * 0.35),
	)


static func _draw_coin(canvas: CanvasItem, c: Vector2, box: float, alpha: float) -> void:
	canvas.draw_circle(c, box * 0.42, Color(UiTheme.COIN_DEEP, alpha))
	canvas.draw_circle(c, box * 0.34, Color(UiTheme.COIN, alpha))
	# 中间的菱形纹样 —— 让它一眼是"金币"而不是"黄球"
	var r: float = box * 0.16
	var pts: PackedVector2Array = PackedVector2Array([
		c + Vector2(0.0, -r),
		c + Vector2(r * 0.62, 0.0),
		c + Vector2(0.0, r),
		c + Vector2(-r * 0.62, 0.0),
	])
	canvas.draw_colored_polygon(pts, Color(UiTheme.COIN_DEEP, alpha * 0.85))


static func _draw_sunny(canvas: CanvasItem, c: Vector2, box: float, alpha: float) -> void:
	var core: Color = Color(1.0, 0.85, 0.24, alpha)
	var ray: Color = Color(1.0, 0.90, 0.45, alpha)
	canvas.draw_circle(c, box * 0.24, core)
	for i: int in 8:
		var angle: float = TAU * float(i) / 8.0
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		canvas.draw_line(
			c + dir * box * 0.31,
			c + dir * box * 0.45,
			ray,
			maxf(1.5, box * 0.055),
		)


## 云 + 降水。storm = true 时把云压暗并加一道闪电。
static func _draw_rain(canvas: CanvasItem, c: Vector2, box: float, alpha: float, storm: bool) -> void:
	var cloud: Color = Color(0.62, 0.66, 0.72, alpha) if storm else Color(0.80, 0.83, 0.87, alpha)
	var cy: float = c.y - box * 0.16
	canvas.draw_circle(Vector2(c.x - box * 0.18, cy), box * 0.17, cloud)
	canvas.draw_circle(Vector2(c.x + box * 0.17, cy), box * 0.15, cloud)
	canvas.draw_circle(Vector2(c.x, cy - box * 0.10), box * 0.21, cloud)
	canvas.draw_rect(
		Rect2(Vector2(c.x - box * 0.30, cy), Vector2(box * 0.60, box * 0.17)),
		cloud,
	)

	if storm:
		var bolt: PackedVector2Array = PackedVector2Array([
			c + Vector2(box * 0.02, box * 0.06),
			c + Vector2(-box * 0.10, box * 0.26),
			c + Vector2(0.0, box * 0.26),
			c + Vector2(-box * 0.06, box * 0.45),
			c + Vector2(box * 0.14, box * 0.20),
			c + Vector2(box * 0.03, box * 0.20),
		])
		canvas.draw_colored_polygon(bolt, Color(1.0, 0.88, 0.28, alpha))
		return

	var drop: Color = Color(0.42, 0.68, 0.92, alpha)
	for i: int in 3:
		var x: float = c.x + (float(i) - 1.0) * box * 0.20
		canvas.draw_line(
			Vector2(x, c.y + box * 0.10),
			Vector2(x - box * 0.05, c.y + box * 0.30),
			drop,
			maxf(1.5, box * 0.06),
		)


static func _draw_snow(canvas: CanvasItem, c: Vector2, box: float, alpha: float) -> void:
	var cloud: Color = Color(0.92, 0.95, 0.99, alpha)
	var cy: float = c.y - box * 0.16
	canvas.draw_circle(Vector2(c.x - box * 0.18, cy), box * 0.17, cloud)
	canvas.draw_circle(Vector2(c.x + box * 0.17, cy), box * 0.15, cloud)
	canvas.draw_circle(Vector2(c.x, cy - box * 0.10), box * 0.21, cloud)
	canvas.draw_rect(Rect2(Vector2(c.x - box * 0.30, cy), Vector2(box * 0.60, box * 0.17)), cloud)

	var flake: Color = Color(1.0, 1.0, 1.0, alpha)
	for i: int in 3:
		var p: Vector2 = Vector2(c.x + (float(i) - 1.0) * box * 0.20, c.y + box * 0.24)
		canvas.draw_circle(p, box * 0.055, flake)


static func _draw_fog(canvas: CanvasItem, c: Vector2, box: float, alpha: float) -> void:
	var band: Color = Color(0.88, 0.91, 0.94, alpha)
	for i: int in 3:
		var y: float = c.y + (float(i) - 1.0) * box * 0.22
		var inset: float = box * 0.10 * float(i % 2)
		canvas.draw_line(
			Vector2(c.x - box * 0.42 + inset, y),
			Vector2(c.x + box * 0.42 - inset, y),
			band,
			maxf(2.0, box * 0.14),
		)


static func _draw_leaf(canvas: CanvasItem, c: Vector2, box: float, tint: Color, alpha: float) -> void:
	var body: Color = Color(tint, alpha)
	_draw_ellipse(canvas, c, box * 0.34, 0.62, -0.72, body)
	canvas.draw_line(
		c + Vector2(box * 0.22, box * 0.22),
		c + Vector2(-box * 0.20, -box * 0.20),
		Color(tint.darkened(0.45), alpha),
		maxf(1.5, box * 0.06),
	)


## 画一个旋转过的椭圆：借助 draw_set_transform 把圆"压扁"再旋转。
static func _draw_ellipse(
	canvas: CanvasItem,
	center: Vector2,
	radius: float,
	squash: float,
	rotation: float,
	color: Color,
) -> void:
	canvas.draw_set_transform(center, rotation, Vector2(1.0, squash))
	canvas.draw_circle(Vector2.ZERO, radius, color)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
