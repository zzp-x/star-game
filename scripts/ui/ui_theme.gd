class_name UiTheme
extends RefCounted
## 星露谷风格的 UI 主题 —— 全部程序化生成，零外部素材。
##
## 【层级】L4 表现层
## 【为什么程序化】和 ProcTextures 同样的理由：保证「克隆下来就能跑」。
##   附带好处是改配色只要改几个常量，试风格极快。
##
## 【星露谷 UI 的质感从哪来】拆开看就四层，缺一层就"差点意思"：
##   ① 粗木框：深棕外描边 → 橙棕木条（带木纹）→ 一线奶油高光
##   ② 硬投影：面板右下有一圈不模糊的深色投影（像素风不用软阴影）
##   ③ 立体格子：快捷栏格子有"凸起"的受光面与落影，按下去才有物理感
##   ④ 选中发光：当前选中的格子泛金光并"浮起"
##   本文件把这四层全部做进 StyleBox，其它 UI 文件只管用。
##
## 【为什么面板用九宫格贴图而不是 StyleBoxFlat】
##   StyleBoxFlat 只能画「单色填充 + 一圈单色边框」，做不出木框的多层结构。
##   九宫格（StyleBoxTexture）拉伸时只有中间那一格被拉，四角与四边变形不变，
##   所以面板无论多大，边框粗细都保持一致。
##
## 【投影为什么"烤"进贴图】StyleBoxTexture 支持 expand_margin ——
##   让九宫格画到控件矩形**之外**。把投影画在贴图右/下的多余区域里，
##   再把 expand_margin_right/bottom 设成投影宽度，控件本身不用改一行代码，
##   每个面板就自动带投影。

# ── 调色板 ───────────────────────────────────────────────

const PARCHMENT: Color = Color(0.98, 0.90, 0.74, 0.97)
const PARCHMENT_DARK: Color = Color(0.89, 0.78, 0.58, 0.97)
## 深棕外描边（星露谷面板的最外一圈）
const WOOD_OUTLINE: Color = Color(0.23, 0.12, 0.05, 1.0)
## 橙棕木条主色 —— 比旧版的 0.60/0.39/0.21 更橙，更接近星露谷
const WOOD_MID: Color = Color(0.78, 0.50, 0.22, 1.0)
const WOOD_DARK: Color = Color(0.42, 0.24, 0.10, 1.0)
const WOOD_LIGHT: Color = Color(0.90, 0.66, 0.34, 1.0)
## 木条内侧那一线奶油高光 —— 星露谷面板立体感的点睛之笔
const EDGE_HIGHLIGHT: Color = Color(0.99, 0.93, 0.78, 1.0)
## 面板投影（像素风的"硬"投影，不模糊）
const PANEL_SHADOW: Color = Color(0.08, 0.04, 0.02, 0.38)

const TEXT_DARK: Color = Color(0.27, 0.15, 0.06, 1.0)
const TEXT_MUTED: Color = Color(0.45, 0.30, 0.17, 1.0)
const TEXT_LIGHT: Color = Color(1.0, 0.97, 0.88, 1.0)
const OUTLINE: Color = Color(0.17, 0.09, 0.03, 0.85)

const GOLD: Color = Color(1.0, 0.84, 0.22, 1.0)
const GOLD_DEEP: Color = Color(0.70, 0.47, 0.06, 1.0)
const COIN: Color = Color(1.0, 0.82, 0.20, 1.0)
const COIN_DEEP: Color = Color(0.78, 0.55, 0.09, 1.0)

const SLOT_FILL: Color = Color(0.87, 0.75, 0.55, 0.98)
const SLOT_FILL_DARK: Color = Color(0.66, 0.52, 0.35, 0.96)
## 工具格用偏冷的灰调 —— 和暖色的种子格拉开距离，
## 玩家扫一眼工具栏就知道"左边三格是家伙什，右边是种子"。
const SLOT_TOOL_FILL: Color = Color(0.78, 0.77, 0.73, 0.98)
const SLOT_TOOL_BORDER: Color = Color(0.36, 0.32, 0.29, 1.0)
const SLOT_SELECTED: Color = Color(1.0, 0.92, 0.42, 1.0)
## 选中格的辉光颜色
const SLOT_GLOW: Color = Color(1.0, 0.86, 0.30, 0.50)

const ENERGY_HIGH: Color = Color(0.36, 0.82, 0.28, 1.0)
const ENERGY_MID: Color = Color(0.93, 0.79, 0.18, 1.0)
const ENERGY_LOW: Color = Color(0.89, 0.29, 0.17, 1.0)

## 季节代表色：春樱粉 / 夏叶绿 / 秋枫橙 / 冬雪蓝
const SEASON_COLORS: Array[Color] = [
	Color(0.97, 0.66, 0.76, 1.0),
	Color(0.55, 0.85, 0.35, 1.0),
	Color(0.94, 0.61, 0.22, 1.0),
	Color(0.68, 0.85, 0.96, 1.0),
]

const FONT_TITLE: int = 26
const FONT_BODY: int = 19
const FONT_SMALL: int = 15

## 贴图与布局的几何参数（单位和像素）。
## 【为什么提出来当常量】贴图边框厚度、九宫格 margin、内容边距三者必须对得上，
##   集中放在一起，改一处时另外两处就在眼前。
## 贴图本体（不含投影）的边长
const PANEL_BODY: int = 72
## 投影在右/下方向超出本体的距离
const PANEL_SHADOW_SIZE: int = 7
## 投影向下偏移（向右不偏，光源习惯上在左上）
const PANEL_SHADOW_DROP: int = 5
## 木框总厚度：描边3 + 木条9 + 高光2 = 14
const PANEL_BORDER: int = 14
## 九宫格 margin：必须 ≥ 边框厚度，且 ≤ 贴图边长一半
const PATCH_MARGIN: int = 20

static var _panel_style: StyleBoxTexture = null
static var _button_normal: StyleBoxTexture = null
static var _button_hover: StyleBoxTexture = null
static var _button_pressed: StyleBoxTexture = null
static var _slot_style: StyleBoxFlat = null
static var _slot_selected_style: StyleBoxFlat = null
static var _slot_empty_style: StyleBoxFlat = null
static var _slot_tool_style: StyleBoxFlat = null
static var _frame_style: StyleBoxFlat = null


# ── 面板 ─────────────────────────────────────────────────

## 木质羊皮纸面板（九宫格 + 右下硬投影，可任意拉伸）。
static func panel_style() -> StyleBoxTexture:
	if _panel_style == null:
		_panel_style = _build_panel_style(0.0)
	return _panel_style


## 一个面板化容器：PanelContainer + 主题样式，直接 add_child 就能用。
static func make_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style())
	return panel


## 嵌在面板里的小圆底衬（图标"勋章"）—— 让图标不直接贴在羊皮纸上。
static func make_medallion(icon: Control, diameter: float) -> PanelContainer:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.34, 0.20, 0.09, 0.30)
	box.set_corner_radius_all(int(diameter * 0.5) + 4)
	box.set_border_width_all(2)
	box.border_color = Color(0.42, 0.24, 0.10, 0.45)
	box.content_margin_left = 6.0
	box.content_margin_right = 6.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0

	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(icon)
	return panel


static func _build_panel_style(brighten: float) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = _build_panel_texture(brighten)
	for margin: String in ["left", "right", "top", "bottom"]:
		style.set("texture_margin_%s" % margin, float(PATCH_MARGIN))
	# 投影要画到控件矩形外 —— 右/下各让出投影宽度
	style.expand_margin_right = float(PANEL_SHADOW_SIZE)
	style.expand_margin_bottom = float(PANEL_SHADOW_SIZE + PANEL_SHADOW_DROP)
	# 内容不要贴着边框（下边略多，给投影留视觉空间）
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 13.0
	style.content_margin_bottom = 16.0
	return style


## 画一张 (72+投影)² 的九宫格源图：三层木框 + 木纹 + 带噪点的羊皮纸底。
##
## 【布局】本体占左上 (0,0)-(72,72)；投影 = 本体矩形向右平移 7、向下平移 5，
##   只画落在本体之外的部分（右带 + 底带 + 折角）。
## 【brighten】按钮三个状态共用同一套画法，只调亮度 ——
##   悬停亮一点、按下暗一点，比换色更接近"木头被光照到"的直觉。
static func _build_panel_texture(brighten: float) -> ImageTexture:
	var size: int = PANEL_BODY + PANEL_SHADOW_SIZE
	var img: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# ① 投影（先画，垫在底下）：本体矩形右移 7 / 下移 5，圆角同本体
	var shift: Vector2i = Vector2i(PANEL_SHADOW_SIZE, PANEL_SHADOW_DROP)
	for x: int in range(shift.x, size):
		for y: int in range(shift.y, size):
			# 只画本体之外的部分，本体区域随后会被面板盖住
			if x < PANEL_BODY and y < PANEL_BODY:
				continue
			if _outside_rounded(x - shift.x, y - shift.y, 4):
				continue
			img.set_pixel(x, y, PANEL_SHADOW)

	# ② 羊皮纸底
	for x: int in PANEL_BODY:
		for y: int in PANEL_BODY:
			if _outside_rounded(x, y, 4):
				continue
			img.set_pixel(x, y, PARCHMENT)

	# 细微噪点 —— 大块纯色在 3D 场景上会显得很"塑料"
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 991
	for _i: int in 340:
		var px: int = rng.randi_range(2, PANEL_BODY - 3)
		var py: int = rng.randi_range(2, PANEL_BODY - 3)
		var base: Color = img.get_pixel(px, py)
		if base.a > 0.5:
			img.set_pixel(px, py, base.lerp(PARCHMENT_DARK, 0.30))

	# ③ 三层木框：深棕描边 → 橙棕木条（带木纹）→ 奶油高光线
	_paint_ring(img, 0, 3, WOOD_OUTLINE)
	_paint_ring(img, 3, 12, _shade(WOOD_MID, brighten))
	# 木条下缘压一道深色，做出"外受光、内落影"的体积
	_paint_ring(img, 10, 12, _shade(WOOD_DARK.lerp(WOOD_MID, 0.5), brighten))
	# 随机木纹短划 —— 只撒在木条带上（第 3~11 圈），羊皮纸区域不受影响
	for _i: int in 46:
		var t: int = rng.randi_range(3, 10)
		var k: int = rng.randi_range(0, PANEL_BODY - 1)
		var span: int = rng.randi_range(2, 5)
		for d: int in span:
			var q: int = mini(k + d, PANEL_BODY - 1)
			var c: Color = img.get_pixel(q, t)
			if c.a > 0.5:
				img.set_pixel(q, t, c.lerp(WOOD_DARK, 0.35))
			var c2: Color = img.get_pixel(t, q)
			if c2.a > 0.5:
				img.set_pixel(t, q, c2.lerp(WOOD_DARK, 0.35))
	# 最内一圈奶油高光 —— 星露谷面板"立体"的关键一笔
	_paint_ring(img, 12, PANEL_BORDER, _shade(EDGE_HIGHLIGHT, brighten))

	# ④ 圆角：把四角外侧的多余像素抠透明（含投影的角）
	for x: int in size:
		for y: int in size:
			if img.get_pixel(x, y).a < 0.01:
				continue
			var lx: int = x - shift.x if x >= shift.x else x
			var ly: int = y - shift.y if y >= shift.y else y
			if _outside_rounded(lx, ly, 4):
				img.set_pixel(x, y, Color(0, 0, 0, 0))

	return ImageTexture.create_from_image(img)


## 判断 (x, y) 是否落在「圆角半径 r 的矩形」外（矩形即 72×72 本体）。
static func _outside_rounded(x: int, y: int, r: int) -> bool:
	if x < 0 or y < 0 or x >= PANEL_BODY or y >= PANEL_BODY:
		return true
	var dx: int = mini(x, PANEL_BODY - 1 - x)
	var dy: int = mini(y, PANEL_BODY - 1 - y)
	if dx >= r or dy >= r:
		return false
	# 到最近角的距离超过 r 就在圆角外
	var corner_dx: int = r - dx
	var corner_dy: int = r - dy
	return corner_dx * corner_dx + corner_dy * corner_dy > r * r


## 沿四条边画一圈 [from, to) 宽度的色带（只在圆角内）。
static func _paint_ring(img: Image, from: int, to: int, color: Color) -> void:
	for k: int in PANEL_BODY:
		for t: int in range(from, to):
			for pos: Vector2i in [
				Vector2i(t, k), Vector2i(PANEL_BODY - 1 - t, k),
				Vector2i(k, t), Vector2i(k, PANEL_BODY - 1 - t),
			]:
				if not _outside_rounded(pos.x, pos.y, 4):
					img.set_pixel(pos.x, pos.y, color)


static func _shade(color: Color, brighten: float) -> Color:
	if brighten >= 0.0:
		return color.lightened(brighten)
	return color.darkened(-brighten)


# ── 快捷栏格子 ───────────────────────────────────────────

static func slot_style() -> StyleBoxFlat:
	if _slot_style == null:
		_slot_style = _build_slot(SLOT_FILL, WOOD_DARK, 3)
	return _slot_style


static func slot_empty_style() -> StyleBoxFlat:
	if _slot_empty_style == null:
		_slot_empty_style = _build_slot(SLOT_FILL_DARK, WOOD_DARK.darkened(0.2), 3)
	return _slot_empty_style


## 工具格：冷调灰底 + 深色边，跟暖色的种子格一眼分得开。
static func slot_tool_style() -> StyleBoxFlat:
	if _slot_tool_style == null:
		_slot_tool_style = _build_slot(SLOT_TOOL_FILL, SLOT_TOOL_BORDER, 3)
	return _slot_tool_style


## 选中格：金色加粗描边 + 金色辉光 —— 一眼能看出"现在拿的是哪个"。
static func slot_selected_style() -> StyleBoxFlat:
	if _slot_selected_style == null:
		_slot_selected_style = _build_slot(
			SLOT_FILL.lightened(0.12), SLOT_SELECTED, 4, SLOT_GLOW,
		)
	return _slot_selected_style


## 【格子的立体感从哪来】StyleBoxFlat 的 shadow 是向下的落影 ——
##   配上上/左的浅色内容、下边框，就得到"凸起的按钮"的错觉。
##   这是像素 UI 里性价比最高的立体画法，不用画任何高光贴图。
static func _build_slot(fill: Color, border: Color, width: int, glow: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.set_border_width_all(width)
	box.border_color = border
	box.set_corner_radius_all(8)
	if glow.a > 0.0:
		box.shadow_color = glow
		box.shadow_size = 8
		box.shadow_offset = Vector2.ZERO
	else:
		box.shadow_color = Color(0.12, 0.06, 0.02, 0.30)
		box.shadow_size = 3
		box.shadow_offset = Vector2(0, 2)
	# 上/左内容略缩，让图标看起来"坐"在格子里
	box.content_margin_left = 4.0
	box.content_margin_right = 4.0
	box.content_margin_top = 3.0
	box.content_margin_bottom = 5.0
	return box


## 体力条等"容器框"用的厚木框。
static func frame_style() -> StyleBoxFlat:
	if _frame_style == null:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Color(0.55, 0.36, 0.18, 1.0)
		box.set_border_width_all(3)
		box.border_color = WOOD_OUTLINE
		box.set_corner_radius_all(9)
		box.shadow_color = Color(0.12, 0.06, 0.02, 0.30)
		box.shadow_size = 3
		box.shadow_offset = Vector2(0, 2)
		_frame_style = box
	return _frame_style


# ── 文字 ─────────────────────────────────────────────────

## 给 Label 套上主题字号与描边。
##
## 【为什么要描边】UI 会压在 3D 场景上，背景亮度不可控。
##   加一圈深色描边是让文字「任何背景下都读得清」最省事的办法。
static func style_label(label: Label, size: int, color: Color, outline: int = 4) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if outline > 0:
		label.add_theme_color_override("font_outline_color", OUTLINE)
		label.add_theme_constant_override("outline_size", outline)


static func make_label(text: String, size: int, color: Color, outline: int = 4) -> Label:
	var label: Label = Label.new()
	label.text = text
	style_label(label, size, color, outline)
	return label


## 给 Button 套上木牌样式：悬停变亮、按下变暗并微微下沉。
##
## 【为什么这次肯画三个状态了】上一版五个状态共用一张样式，"按下去没反应"
##   是暂停菜单被吐槽的一部分原因。现在按钮的三个贴图由同一套画法 + 亮度参数
##   生成（见 _build_panel_texture），代码没有多一个量级，手感却完全不同。
##   focus 用空样式 —— 否则键盘焦点框会叠在木框外面很丑。
static func style_button(button: Button, font_size: int = FONT_BODY) -> void:
	if _button_normal == null:
		_button_normal = _build_panel_style(0.0)
	if _button_hover == null:
		_button_hover = _build_panel_style(0.05)
	if _button_pressed == null:
		_button_pressed = _build_panel_style(-0.06)
	button.add_theme_stylebox_override("normal", _button_normal)
	button.add_theme_stylebox_override("hover", _button_hover)
	button.add_theme_stylebox_override("pressed", _button_pressed)
	button.add_theme_stylebox_override("disabled", _button_normal)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", TEXT_DARK)
	button.add_theme_color_override("font_hover_color", GOLD_DEEP)
	button.add_theme_color_override("font_pressed_color", WOOD_DARK)
	button.add_theme_color_override("font_focus_color", TEXT_DARK)


## 按当前体力比例取颜色：绿 → 黄 → 红。
static func energy_color(ratio: float) -> Color:
	if ratio > 0.55:
		return ENERGY_HIGH
	if ratio > 0.25:
		return ENERGY_MID
	return ENERGY_LOW
