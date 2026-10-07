class_name UiTheme
extends RefCounted
## 星露谷风格的 UI 主题 —— 全部程序化生成，零外部素材。
##
## 【层级】L4 表现层
## 【为什么程序化】和 ProcTextures 同样的理由：保证「克隆下来就能跑」。
##   附带好处是改配色只要改几个常量，试风格极快。
##
## 【为什么面板用九宫格贴图而不是 StyleBoxFlat】
##   StyleBoxFlat 只能画「单色填充 + 一圈边框」，做不出木质面板那种
##   「深棕外描边 → 中棕木条 → 浅黄高光 → 羊皮纸底」的层次。
##   九宫格（StyleBoxTexture）拉伸时只有中间那一格被拉，四角与四边变形不变，
##   所以面板无论多大，边框粗细都保持一致。
##
## 【配色说明】取的是星露谷界面的同色系近似值，不是抄具体像素值。
##   基调就是「木质边框 + 羊皮纸底 + 深棕字 + 金色数字」。

# ── 调色板 ───────────────────────────────────────────────

const PARCHMENT: Color = Color(0.98, 0.90, 0.74, 0.97)
const PARCHMENT_DARK: Color = Color(0.89, 0.78, 0.58, 0.97)
const WOOD_DARK: Color = Color(0.28, 0.16, 0.07, 1.0)
const WOOD_MID: Color = Color(0.60, 0.39, 0.21, 1.0)
const WOOD_LIGHT: Color = Color(0.87, 0.68, 0.43, 1.0)

const TEXT_DARK: Color = Color(0.27, 0.15, 0.06, 1.0)
const TEXT_MUTED: Color = Color(0.45, 0.30, 0.17, 1.0)
const TEXT_LIGHT: Color = Color(1.0, 0.97, 0.88, 1.0)
const OUTLINE: Color = Color(0.17, 0.09, 0.03, 0.85)

const GOLD: Color = Color(1.0, 0.84, 0.22, 1.0)
const GOLD_DEEP: Color = Color(0.70, 0.47, 0.06, 1.0)
const COIN: Color = Color(1.0, 0.82, 0.20, 1.0)
const COIN_DEEP: Color = Color(0.78, 0.55, 0.09, 1.0)

const SLOT_FILL: Color = Color(0.84, 0.71, 0.51, 0.97)
const SLOT_FILL_DARK: Color = Color(0.62, 0.48, 0.31, 0.95)
const SLOT_SELECTED: Color = Color(1.0, 0.94, 0.46, 1.0)

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

## 九宫格的边距 —— 必须 ≥ 贴图里边框的总厚度（2+6+4=12）
const PATCH_MARGIN: int = 14

static var _panel_style: StyleBoxTexture = null
static var _slot_style: StyleBoxFlat = null
static var _slot_selected_style: StyleBoxFlat = null
static var _slot_empty_style: StyleBoxFlat = null


# ── 面板 ─────────────────────────────────────────────────

## 木质羊皮纸面板（九宫格，可任意拉伸）。
static func panel_style() -> StyleBoxTexture:
	if _panel_style == null:
		_panel_style = _build_panel_style()
	return _panel_style


## 一个面板化容器：PanelContainer + 主题样式，直接 add_child 就能用。
static func make_panel() -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", panel_style())
	return panel


static func _build_panel_style() -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = _build_panel_texture()
	style.texture_margin_left = PATCH_MARGIN
	style.texture_margin_right = PATCH_MARGIN
	style.texture_margin_top = PATCH_MARGIN
	style.texture_margin_bottom = PATCH_MARGIN
	# 内容不要贴着边框
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


## 画一张 48×48 的九宫格源图：三层木框 + 带噪点的羊皮纸底。
static func _build_panel_texture() -> ImageTexture:
	var size: int = 48
	var img: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(PARCHMENT)

	# 细微噪点 —— 大块纯色在 3D 场景上会显得很"塑料"
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 991
	for _i: int in 320:
		var x: int = rng.randi_range(0, size - 1)
		var y: int = rng.randi_range(0, size - 1)
		img.set_pixel(x, y, img.get_pixel(x, y).lerp(PARCHMENT_DARK, 0.34))

	# 由外向内：深棕描边 → 中棕木条 → 浅黄高光
	_paint_ring(img, 0, 2, WOOD_DARK)
	_paint_ring(img, 2, 8, WOOD_MID)
	_paint_ring(img, 8, 12, WOOD_LIGHT)

	return ImageTexture.create_from_image(img)


## 沿四条边画一圈 [from, to) 宽度的色带。
static func _paint_ring(img: Image, from: int, to: int, color: Color) -> void:
	var size: int = img.get_width()
	for k: int in size:
		for t: int in range(from, to):
			img.set_pixel(t, k, color)
			img.set_pixel(size - 1 - t, k, color)
			img.set_pixel(k, t, color)
			img.set_pixel(k, size - 1 - t, color)


# ── 快捷栏格子 ───────────────────────────────────────────

static func slot_style() -> StyleBoxFlat:
	if _slot_style == null:
		_slot_style = _build_slot(SLOT_FILL, WOOD_MID, 2)
	return _slot_style


static func slot_empty_style() -> StyleBoxFlat:
	if _slot_empty_style == null:
		_slot_empty_style = _build_slot(SLOT_FILL_DARK, WOOD_MID.darkened(0.25), 2)
	return _slot_empty_style


## 选中格：加粗的亮黄边 —— 一眼能看出"现在拿的是哪个"。
static func slot_selected_style() -> StyleBoxFlat:
	if _slot_selected_style == null:
		_slot_selected_style = _build_slot(SLOT_FILL.lightened(0.10), SLOT_SELECTED, 4)
	return _slot_selected_style


static func _build_slot(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.set_border_width_all(width)
	box.border_color = border
	box.set_corner_radius_all(5)
	return box


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


## 按当前体力比例取颜色：绿 → 黄 → 红。
static func energy_color(ratio: float) -> Color:
	if ratio > 0.55:
		return ENERGY_HIGH
	if ratio > 0.25:
		return ENERGY_MID
	return ENERGY_LOW
