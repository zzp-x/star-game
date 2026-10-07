class_name PauseMenu
extends CanvasLayer
## 暂停菜单 —— 继续游戏 / 保存进度 / 保存并退出 / 退出游戏。
##
## 【层级】L4 表现层
##
## 【为什么单独一个 CanvasLayer，而不是挂在 Hud 下面】
##   ① Hud 里所有控件都被递归设成**鼠标穿透**（否则点在快捷栏上的左键会被 GUI 吃掉，
##      田地就点不动了），而菜单按钮**必须**能点到 —— 两者的要求正好相反，
##      塞在同一棵树里只会互相打架。
##   ② 暂停时 `get_tree().paused = true`，Hud 会跟着停住；
##      菜单却必须在暂停中继续响应输入，所以它要 PROCESS_MODE_ALWAYS。
##   层号取 20（Hud 是 10），保证菜单压在 HUD 上面。
##
## 【时间系统要单独处理 · 容易漏】TimeManager 是 PROCESS_MODE_ALWAYS
##   （这样暂停时调试键还能用），所以**场景树暂停并不能停住游戏时钟**。
##   这里必须显式关掉 auto_advance —— 否则暂停十分钟再回来，天已经黑了。
##   这一条是"暂停看起来正常、实际在偷偷流逝"的典型陷阱。
##
## 【为什么"退出"不直接 quit 就完事】先解除暂停再退。
##   Godot 退出时会走一遍节点清理，树还处于 paused 状态时
##   部分逻辑（含自动加载单例的收尾）不会按预期执行。

const DESIGN_HEIGHT: float = 1080.0
const MARGIN: float = 26.0
const BUTTON_WIDTH: float = 268.0
## 右上角常驻按钮的尺寸
const MENU_BUTTON_WIDTH: float = 150.0
const MENU_BUTTON_HEIGHT: float = 46.0
## 暂停时默认保存到 1 号槽（M2 会做存档选择界面）
const QUICK_SAVE_SLOT: int = 1

var _root: Control = null
var _ui_scale: float = 1.0
var _menu_button: Button = null
var _overlay: Control = null
var _note: Label = null
var _resume_button: Button = null
var _is_open: bool = false


func _ready() -> void:
	layer = 20
	# 暂停中也要收 ESC、也要能点按钮
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 加组便于"从别处找到菜单"（截图脚本、将来的"战斗中禁止暂停"等规则）
	add_to_group("pause_menu")

	_root = Control.new()
	_root.name = "PauseRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_update_scale()

	_build_menu_button()
	_build_overlay()
	_overlay.visible = false
	_menu_button.visible = true


func _process(_delta: float) -> void:
	_update_scale()


func _update_scale() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.y <= 1.0:
		return
	_ui_scale = clampf(viewport_size.y / DESIGN_HEIGHT, 0.62, 2.2)
	_root.scale = Vector2(_ui_scale, _ui_scale)
	_root.size = viewport_size / _ui_scale


# ── 常驻按钮 ─────────────────────────────────────────────

func _build_menu_button() -> void:
	_menu_button = Button.new()
	_menu_button.text = "菜单 ESC"
	# 常驻按钮不抢焦点：否则按空格/回车会把它按下去
	_menu_button.focus_mode = Control.FOCUS_NONE
	UiTheme.style_button(_menu_button, UiTheme.FONT_SMALL)
	_menu_button.anchor_left = 1.0
	_menu_button.anchor_right = 1.0
	_menu_button.anchor_top = 0.0
	_menu_button.anchor_bottom = 0.0
	_menu_button.offset_right = -MARGIN
	_menu_button.offset_left = -MARGIN - MENU_BUTTON_WIDTH
	_menu_button.offset_top = MARGIN
	_menu_button.offset_bottom = MARGIN + MENU_BUTTON_HEIGHT
	_menu_button.pressed.connect(toggle)
	_root.add_child(_menu_button)


# ── 暂停浮层 ─────────────────────────────────────────────

func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.name = "PauseOverlay"
	# STOP 而不是 IGNORE：浮层要挡住底下场景/UI 的所有点击
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_overlay)

	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.02, 0.64)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel: PanelContainer = UiTheme.make_panel()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(BUTTON_WIDTH + 48.0, 0.0)
	center.add_child(panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	var title: Label = UiTheme.make_label("游戏暂停", UiTheme.FONT_TITLE, UiTheme.TEXT_DARK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)

	_resume_button = _add_action(column, "继续游戏", _on_resume)
	_add_action(column, "保存进度", _on_save)
	_add_action(column, "保存并退出", _on_save_and_quit)
	_add_action(column, "退出游戏", _on_quit)

	_note = UiTheme.make_label("", UiTheme.FONT_SMALL, UiTheme.TEXT_MUTED, 3)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_note)


func _add_action(parent: VBoxContainer, text: String, handler: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, 0.0)
	button.focus_mode = Control.FOCUS_ALL
	UiTheme.style_button(button, UiTheme.FONT_BODY)
	button.pressed.connect(handler)
	parent.add_child(button)
	return button


# ── 开关 ─────────────────────────────────────────────────

func toggle() -> void:
	set_open(not _is_open)


func is_open() -> bool:
	return _is_open


func set_open(value: bool) -> void:
	if _is_open == value:
		return
	_is_open = value

	_overlay.visible = _is_open
	_menu_button.visible = not _is_open
	get_tree().paused = _is_open
	# 见文件头：场景树暂停**停不住**游戏时钟，必须显式关掉
	TimeManager.auto_advance = not _is_open

	if _is_open:
		_note.text = "退出游戏会丢失未保存的进度"
		# 焦点交给「继续游戏」，回车即可返回
		_resume_button.grab_focus()


# ── 按钮回调 ─────────────────────────────────────────────

func _on_resume() -> void:
	set_open(false)


func _on_save() -> void:
	if SaveManager.save_game(QUICK_SAVE_SLOT):
		_note.text = "已保存到存档位 %d" % QUICK_SAVE_SLOT
	else:
		_note.text = "保存失败，请查看日志输出"


func _on_save_and_quit() -> void:
	SaveManager.save_game(QUICK_SAVE_SLOT)
	_quit()


func _on_quit() -> void:
	_quit()


func _quit() -> void:
	# 先解除暂停再退（见文件头最后一段）
	get_tree().paused = false
	TimeManager.auto_advance = true
	get_tree().quit()


# ── 输入 ─────────────────────────────────────────────────

## ESC 开关菜单。暂停时本节点仍会收到输入（PROCESS_MODE_ALWAYS）。
func _unhandled_input(event: InputEvent) -> void:
	# 注意：不能用 `event is InputEventKey and event.pressed` ——
	# `and` 链不会让分析器收窄类型，会报 "property not present"（属性不存在）。
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_ESCAPE:
		toggle()
		get_viewport().set_input_as_handled()
