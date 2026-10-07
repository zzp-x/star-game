extends Node
## 【临时脚本 · 只用于实机截图验收，验收完就删】
##
## 为什么需要它：`--write-movie` 渲染的是真实游戏，但**没有输入**。
## 想看到"走路中的角色"和"暂停菜单"，就必须有人替玩家按键。
## 这里在 _ready 里直接按住 W（走），并按环境变量决定是否弹出暂停菜单。
##
## 用法：
##   godot --path <项目> res://scenes/_debug_shot.tscn --write-movie out.png --fixed-fps 30 --quit-after 40
##   加上 SG_DEBUG_PAUSE=1 则渲染"暂停菜单打开"的画面。

const WALK_START_FRAME: int = 86
const OPEN_PAUSE_AFTER_FRAMES: int = 6

var _frames: int = 0
var _want_pause: bool = false


func _ready() -> void:
	_want_pause = OS.get_environment("SG_DEBUG_PAUSE") != ""
	if not _want_pause:
		# 延迟到第 86 帧才开始走：开局那条日期横幅要 2.8 秒（约 84 帧）才淡完，
		# 太早迈步的话角色会被横幅盖住，根本看不清姿态。
		# 也不跑步 —— 跑 6.6 米/秒会撞上围栏，撞墙后动画收住就拍不到迈步了。
		pass


func _process(_delta: float) -> void:
	if _want_pause:
		_frames += 1
		if _frames == OPEN_PAUSE_AFTER_FRAMES:
			var menu: PauseMenu = get_tree().get_first_node_in_group("pause_menu") as PauseMenu
			if menu != null:
				menu.set_open(true)
		return

	if _frames == WALK_START_FRAME:
		Input.action_press("move_forward")
	_frames += 1
