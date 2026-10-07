class_name Hud
extends CanvasLayer
## 星露谷风格的游戏 HUD —— 全部 UI 在代码里构建，不依赖任何美术资源。
##
## 【层级】L4 表现层 —— 只读游戏状态，不改。
##
## 【布局】完全照星露谷的方位：
##   右上角  日期（季节+日+年）→ 时间 + 天气 → 金钱
##   右下角  竖直体力条
##   底部中央 12 格快捷栏（当前选中的种子会高亮）
##   左下角  消息条（"翻地""播种 芜菁"…）
##   鼠标旁  指向格子的信息气泡
##
## 【为什么不放常驻帮助面板】M0.5 曾有一个左上角键位表，但它占了画面、
##   又和"鼠标旁气泡"重复表达同一件事（能做什么）。键位说明属于**开场信息**，
##   放在 README 与启动横幅里就够了，游戏画面留给游戏本身。
##
## 【为什么要自己做缩放】项目把 Stretch Mode 设成了 disabled
##   （3D 必须按原生分辨率渲染，见 DESIGN.md §5.1），
##   所以 UI 不会自动跟着窗口缩放。这里用一个「设计画布」Control
##   统一缩放：所有布局都按 1920×1080 写死像素，缩放由根节点一次搞定。
##
## 【鼠标穿透 · 关键】所有 HUD 控件都必须设成 MOUSE_FILTER_IGNORE，
##   否则点在快捷栏上的鼠标左键会被 GUI 吃掉，
##   FarmView 的 _unhandled_input 收不到 → 站在快捷栏前面就没法操作田地。

const DESIGN_HEIGHT: float = 1080.0
const MARGIN: float = 26.0
const MAX_TOASTS: int = 3
## 右上角留给常驻「菜单」按钮的高度 —— 状态面板要往下让开这一条
const MENU_BAND: float = 56.0

var _root: Control = null
var _ui_scale: float = 1.0

var _status: HudStatus = null
var _hotbar: HudHotbar = null
var _energy: HudEnergy = null

var _tooltip: PanelContainer = null
var _tooltip_label: Label = null

var _toast_box: VBoxContainer = null
var _toasts: Array[HudToast] = []

var _banner_box: PanelContainer = null
var _banner: Label = null
var _banner_tween: Tween = null

var _farm_view: FarmView = null


func _ready() -> void:
	layer = 10

	# 设计画布：所有子控件都按 1920×1080 的坐标写，缩放只在这一层做
	_root = Control.new()
	_root.name = "UiRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_update_scale()

	_build_status()
	_build_hotbar()
	_build_energy()
	_build_tooltip()
	_build_toasts()
	_build_banner()

	_make_click_through(self)
	_root.queue_redraw()

	EventBus.toast.connect(_on_toast)
	EventBus.day_changed.connect(_on_day_changed)

	_show_banner("第 %d 年 · %s %d 日 · %s" % [
		TimeManager.clock.year,
		TimeManager.clock.season_name(),
		TimeManager.clock.day,
		TimeManager.weather_name(),
	])


func _process(_delta: float) -> void:
	_update_scale()
	_update_tooltip()
	_prune_toasts()


# ── 缩放 ─────────────────────────────────────────────────

func _update_scale() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.y <= 1.0:
		return
	# 钳制上下限：极小窗口下文字不至于糊成一团，4K 下也不至于占满半屏
	_ui_scale = clampf(viewport_size.y / DESIGN_HEIGHT, 0.62, 2.2)
	_root.scale = Vector2(_ui_scale, _ui_scale)
	_root.size = viewport_size / _ui_scale


# ── 各区域 ───────────────────────────────────────────────

func _build_status() -> void:
	_status = HudStatus.new()
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.anchor_left = 1.0
	_status.anchor_right = 1.0
	_status.anchor_top = 0.0
	_status.anchor_bottom = 0.0
	_status.offset_left = -MARGIN - 200.0
	_status.offset_right = -MARGIN
	# 顶部留出 MENU_BAND —— 右上角那一格被常驻的「菜单」按钮占了（见 PauseMenu）
	_status.offset_top = MARGIN + MENU_BAND
	_status.offset_bottom = MARGIN + MENU_BAND + 320.0
	_root.add_child(_status)


func _build_hotbar() -> void:
	_hotbar = HudHotbar.new()
	_hotbar.anchor_left = 0.5
	_hotbar.anchor_right = 0.5
	_hotbar.anchor_top = 1.0
	_hotbar.anchor_bottom = 1.0
	_hotbar.offset_bottom = -MARGIN
	_root.add_child(_hotbar)

	# custom_minimum_size 是在 hotbar 的 _ready 里算出来的，
	# add_child 之后就能读到 —— 据此把它水平居中
	var half_width: float = _hotbar.custom_minimum_size.x * 0.5
	_hotbar.offset_left = -half_width
	_hotbar.offset_right = half_width
	_hotbar.offset_top = -_hotbar.custom_minimum_size.y - MARGIN


func _build_energy() -> void:
	_energy = HudEnergy.new()
	_energy.anchor_left = 1.0
	_energy.anchor_right = 1.0
	_energy.anchor_top = 1.0
	_energy.anchor_bottom = 1.0
	_energy.offset_right = -MARGIN
	_energy.offset_left = -MARGIN - HudEnergy.BAR_WIDTH
	_energy.offset_bottom = -MARGIN - 14.0
	_energy.offset_top = _energy.offset_bottom - HudEnergy.BAR_HEIGHT
	_root.add_child(_energy)


func _build_tooltip() -> void:
	_tooltip = UiTheme.make_panel()
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.visible = false
	_tooltip_label = UiTheme.make_label("", UiTheme.FONT_BODY, UiTheme.TEXT_DARK, 0)
	_tooltip.add_child(_tooltip_label)
	_root.add_child(_tooltip)


func _build_toasts() -> void:
	_toast_box = VBoxContainer.new()
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.alignment = BoxContainer.ALIGNMENT_END
	_toast_box.add_theme_constant_override("separation", 6)
	_toast_box.anchor_top = 1.0
	_toast_box.anchor_bottom = 1.0
	_toast_box.offset_left = MARGIN
	_toast_box.offset_right = MARGIN + 560.0
	_toast_box.offset_top = -(MARGIN + 320.0)
	_toast_box.offset_bottom = -MARGIN
	_root.add_child(_toast_box)


func _build_banner() -> void:
	# 木牌横幅：裸文字压在 3D 画面上没有"落款"的仪式感，
	# 一块带投影的木牌让"新的一天开始了"更像一个正式的事件。
	_banner_box = UiTheme.make_panel()
	_banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_box.visible = false

	_banner = UiTheme.make_label("", 40, UiTheme.TEXT_DARK, 0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner_box.add_child(_banner)
	_root.add_child(_banner_box)


# ── 刷新 ─────────────────────────────────────────────────

func _update_tooltip() -> void:
	if _farm_view == null:
		_farm_view = get_tree().get_first_node_in_group("farm_view") as FarmView

	if _farm_view == null:
		_tooltip.visible = false
		return

	var cell: Vector2i = _farm_view.hovered_cell()
	if cell == FarmView.NO_CELL:
		_tooltip.visible = false
		return

	_tooltip_label.text = _describe_cell(cell)
	_tooltip.reset_size()
	_tooltip.visible = true

	# 鼠标坐标要换算到「设计画布」的坐标系里（画布被整体缩放过）
	var mouse: Vector2 = get_viewport().get_mouse_position() / _ui_scale
	var target: Vector2 = mouse + Vector2(22.0, 18.0)
	var limit: Vector2 = _root.size - _tooltip.size - Vector2(8.0, 8.0)
	target.x = clampf(target.x, 8.0, maxf(8.0, limit.x))
	target.y = clampf(target.y, 8.0, maxf(8.0, limit.y))
	_tooltip.position = target


## 格位信息的玩家向文案。
##
## 【为什么不放在 GameManager 里】那是"调试视角"的描述（带坐标、用词偏技术），
##   而且描述要跟着"手上拿着什么"变 —— 手持物是 UI 才关心的概念。
##   放在表现层，规则判断仍然全部留在 L2/L3，这里只是"挑词"。
##
## 【为什么要把手持物算进来】M0.5 起"能做什么"取决于"手上拿什么"。
##   只说"荒草地 —— 可以开垦"的话，拿着水壶点上去毫无反应，
##   玩家会以为游戏坏了。提示必须跟着手持物走。
func _describe_cell(cell: Vector2i) -> String:
	var tile: FarmTile = GameManager.farm.peek(cell)
	var hand: HotbarEntry = GameManager.selected_entry()

	if tile == null or tile.state == FarmTile.State.UNTILLED:
		return "荒草地 · %s" % _hand_hint(hand, ToolData.Verb.TILL, "拿锄头翻地")

	if not tile.has_crop():
		return "已翻好的土 · 拿种子播种 / 拿水壶浇水"

	var data: CropData = CropDatabase.get_crop(tile.crop_id)
	if data == null:
		return "未知作物"
	if data.is_mature(tile.growth):
		return "%s 已成熟 · %s" % [
			data.display_name, _hand_hint(hand, ToolData.Verb.HARVEST, "拿镰刀收割"),
		]
	if tile.state == FarmTile.State.WATERED:
		return "%s · 生长 %d/%d 天 · 已浇水" % [data.display_name, tile.growth, data.mature_days]
	return "%s · 生长 %d/%d 天 · %s" % [
		data.display_name,
		tile.growth,
		data.mature_days,
		_hand_hint(hand, ToolData.Verb.WATER, "拿水壶浇水"),
	]


## 手持物正好是干这事的那件工具 → 说"可以动手"；否则直接提示该换什么。
func _hand_hint(hand: HotbarEntry, verb: int, fallback: String) -> String:
	if hand != null and hand.is_tool() and hand.verb == verb:
		return "可以动手"
	return fallback


# ── 消息条 ───────────────────────────────────────────────

func _on_toast(text: String) -> void:
	var toast: HudToast = HudToast.make(text)
	_toast_box.add_child(toast)
	_make_click_through(toast)
	_toasts.append(toast)
	# 超出上限就丢掉最老的，避免消息刷屏挡住画面
	while _toasts.size() > MAX_TOASTS:
		var oldest: HudToast = _toasts.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()


## 清掉已经自己销毁掉的条目，避免列表里堆悬空引用。
func _prune_toasts() -> void:
	if _toasts.is_empty():
		return
	var alive: Array[HudToast] = []
	for toast: HudToast in _toasts:
		if is_instance_valid(toast):
			alive.append(toast)
	_toasts = alive


# ── 跨天横幅 ─────────────────────────────────────────────

func _on_day_changed(_day: int, _season: int) -> void:
	_show_banner("第 %d 年 · %s %d 日 · %s" % [
		TimeManager.clock.year,
		TimeManager.clock.season_name(),
		TimeManager.clock.day,
		TimeManager.weather_name(),
	])


## 跨天时中央浮出一块日期木牌，再淡掉 —— 给玩家一个"新的一天开始了"的锚点。
func _show_banner(text: String) -> void:
	if _banner_box == null:
		return
	_banner.text = text
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()

	# 面板是自适应大小的，先让它算好尺寸再居中、再定缩放轴心
	_banner_box.reset_size()
	_banner_box.position = (_root.size - _banner_box.size) * 0.5 + Vector2(0.0, -150.0)
	_banner_box.pivot_offset = _banner_box.size * 0.5

	_banner_box.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_banner_box.scale = Vector2(0.86, 0.86)
	_banner_box.visible = true

	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(_banner_box, "modulate:a", 1.0, 0.30)
	_banner_tween.tween_property(_banner_box, "scale", Vector2.ONE, 0.45) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.set_parallel(false)
	_banner_tween.tween_interval(1.7)
	_banner_tween.tween_property(_banner_box, "modulate:a", 0.0, 0.8)
	_banner_tween.tween_callback(func() -> void: _banner_box.visible = false)


# ── 输入 ─────────────────────────────────────────────────

## 调试快捷键：F5 存档 / F9 读档（正式版会换成菜单）
func _unhandled_input(event: InputEvent) -> void:
	# 注意：不能用 `event is InputEventKey and event.pressed` ——
	# `and` 链不会让分析器收窄类型，会报 "property not present"（属性不存在）。
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return

	match key.physical_keycode:
		KEY_F5:
			SaveManager.save_game(1)
			EventBus.toast.emit("已存档")
			get_viewport().set_input_as_handled()
		KEY_F9:
			if SaveManager.load_game(1):
				EventBus.toast.emit("已读档")
				var view: FarmView = get_tree().get_first_node_in_group("farm_view") as FarmView
				if view != null:
					view.refresh_all()
			else:
				EventBus.toast.emit("没有找到存档")
			get_viewport().set_input_as_handled()


## 递归把 HUD 里所有控件设成鼠标穿透（见文件头「鼠标穿透」）。
func _make_click_through(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in node.get_children():
		_make_click_through(child)
