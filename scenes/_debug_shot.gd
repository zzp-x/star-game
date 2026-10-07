extends Node
## 【临时脚本 · 只用于实机截图验收，验收完就删】
##
## 为什么需要它：真实游戏没有输入，想看到"走路中的角色"就得有人替玩家按键。
##
## 【为什么用视口自截图而不是 --write-movie】Movie 模式的窗口会被系统
##   压到屏幕工作区以内（1920×1080 的请求实际开成 ~1875×1054），而 PNG
##   帧按 1920×1080 写出 → 全画面被拉伸 ~2.4%，截图里"面板顶到屏幕边"
##   其实是拉出来的假象。视口自截图拿到的就是未缩放的原生渲染。
##
## 【为什么 PROCESS_MODE_ALWAYS】SG_DEBUG_PAUSE=1 会在第 6 帧打开暂停菜单，
##   场景树一暂停，INHERIT 节点的 _process 就停了 —— 拍暂停画面的人
##   自己必须活过暂停，所以本节点要 ALWAYS。
##
## 用法（普通窗口运行，不用 --write-movie）：
##   godot --path <项目> res://scenes/_debug_shot.tscn --quit-after 200
## 环境变量：
##   SG_SHOT_FRAMES=30,120   在这些逻辑帧各存一张 PNG（必填，否则什么都不拍）
##   SG_SHOT_WALK=1          第 86 帧起按住 W（走路；等开场横幅淡完）
##   SG_DEBUG_PAUSE=1        第 6 帧打开暂停菜单（优先于走路）

const WALK_START_FRAME: int = 86
const OPEN_PAUSE_AFTER_FRAMES: int = 6
const SHOT_DIR: String = "D:/WorkBuddy-work-space/_backup/shots_vp"

var _frames: int = 0
var _want_pause: bool = false
var _want_walk: bool = false
## 待拍摄的帧号集合
var _pending: Dictionary[int, int] = {}


func _ready() -> void:
	# 见文件头：拍"暂停菜单"的人必须活过暂停
	process_mode = Node.PROCESS_MODE_ALWAYS
	_want_pause = OS.get_environment("SG_DEBUG_PAUSE") != ""
	_want_walk = OS.get_environment("SG_SHOT_WALK") != ""
	var spec: String = OS.get_environment("SG_SHOT_FRAMES")
	if spec.is_empty():
		return
	for token: String in spec.split(",", false):
		var frame: int = int(token)
		if frame > 0:
			_pending[frame] = frame


func _process(_delta: float) -> void:
	_frames += 1
	if _want_pause:
		if _frames == OPEN_PAUSE_AFTER_FRAMES:
			var menu: PauseMenu = get_tree().get_first_node_in_group("pause_menu") as PauseMenu
			if menu != null:
				menu.set_open(true)
	elif _want_walk and _frames == WALK_START_FRAME:
		Input.action_press("move_forward")

	if _pending.has(_frames):
		_capture(_frames)
		_pending.erase(_frames)


## 抓当前帧的视口图像存盘（与屏幕所见 1:1，无任何窗口缩放）。
func _capture(frame: int) -> void:
	await RenderingServer.frame_post_draw
	var shot: Image = get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	var path: String = "%s/frame_%05d.png" % [SHOT_DIR, frame]
	shot.save_png(path)
	print("[_debug_shot] 已保存 ", path, " ", shot.get_size())
