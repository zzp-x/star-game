class_name Player
extends CharacterBody3D
## 玩家控制器（3D）。
##
## 【层级】L4 表现层 —— 只做「输入采集 + 移动 + 走路动画」，不含任何游戏规则。
##
## 【关键手感 1 · 相对相机移动】移动方向是**相对相机**的：按 A 永远是"屏幕左"，
##   这样相机 90° 旋转之后操作逻辑完全不变（见 DESIGN.md §3.3 / §5.3）。
##
## 【关键手感 2 · 朝向约定】Godot 里节点的"正前方"是局部 **−Z**（不是 +Z）。
##   所以朝向要用 atan2(−dir.x, −dir.z)，否则角色会**倒着走** ——
##   脸在 −Z 却没转过去，看起来像后退。这个 bug 很隐蔽，因为"能走"看不出来。
##
## 【关键手感 3 · 走路动画】见 `_animate_visual`。三条要点，缺一条就回到"僵尸步"：
##   ① **绕关节转，不是绕自己中心转** —— 所以 player.tscn 里每根肢体都挂在
##      位于髋 / 肩的空 Node3D 枢轴下面，网格再往下偏移半根长度。
##      少了这层枢轴，四肢就变成在原地打转的火柴棍。
##   ② **左臂与左腿反相**（左腿前 → 左臂后）。同手同脚是一眼假的根源。
##   ③ **幅度按"步态权重"渐变、频率按速度走** —— 起步是"逐渐迈开"而不是
##      "瞬间开始摆"，跑起来步频要更快。少了这条，走和跑的动画会一模一样。
##
## 【3D 新手最容易踩的坑】Vector3 的 y 是"上"，不是"里"。
##   地面平面用 x/z，高度用 y。把 Vector3 当 Vector2 用会得到诡异的移动。

const WALK_SPEED: float = 4.2
const RUN_SPEED: float = 6.6
const ACCELERATION: float = 45.0
const FRICTION: float = 55.0
const GRAVITY: float = 24.0
const TURN_SPEED: float = 12.0

## 每秒完成的完整步态周期数（走路 / 跑步）。
## 【为什么跑步要更快】步频不变、只是走得更快，看起来就是"在地上滑行的雕像"。
const STRIDE_WALK: float = 1.60
const STRIDE_RUN: float = 2.35
## 腿 / 臂的摆动幅度（弧度）。腿比臂大是正常的 —— 步幅主要由腿决定。
const LEG_SWING: float = 0.95
const ARM_SWING: float = 0.70
## 跑步时额外放大的倍数（腿摆得更开）
const RUN_SWING_BOOST: float = 0.18
## 手臂默认往外张开的弧度。
## 【为什么必须张开】手臂枢轴离躯干只有 0.06 米余量，摆动时会**穿进躯干**里，
##   看起来像手插在身体里晃。
const ARM_SPREAD: float = 0.14
## 整体上下起伏（米）与左右侧倾（弧度）
const BOB_HEIGHT: float = 0.055
const BODY_ROLL: float = 0.045
## 前倾角（弧度）：走路微微前倾，跑步明显前倾
const LEAN_WALK: float = 0.05
const LEAN_RUN: float = 0.17
## 待机呼吸：幅度（米）与每秒周期数（很慢，是"活着"而不是"喘气"）
const BREATH_AMPLITUDE: float = 0.013
const BREATH_FREQUENCY: float = 0.55
## 头部反向摆动的幅度（弧度）
const HEAD_SWAY: float = 0.030
## 步态权重（0 = 站定，1 = 全速迈步）的平滑速度。
## 太小会"飘"，太大会让起步/停步像硬切动画。
const GAIT_BLEND_SPEED: float = 8.0
## 手里工具相对手臂的倾角 —— 让工具朝前平端，而不是垂在腿边
const TOOL_PROP_TILT: float = -1.35

## 相机偏航角（度），由 CameraRig 每帧写入 —— 这是"相对相机移动"的基准。
var camera_yaw_degrees: float = 0.0
## 是否正在奔跑
var is_running: bool = false
## 0～1 的移动强度，到走路速度即满。供动画与音效使用（0 = 站着）
var move_ratio: float = 0.0
## 0～1 的"奔跑程度"，从走路速度开始涨、到跑步速度满。
## 【为什么要和 move_ratio 分开】move_ratio 在走路速度就饱和了，
##   拿它去插值"跑才有的效果"（更快步频、更大前倾）会导致**走路和跑步的动画一样**。
var run_ratio: float = 0.0

@onready var _visual: Node3D = $Visual
@onready var _upper: Node3D = $Visual/Upper
@onready var _leg_left: Node3D = $Visual/LegPivotLeft
@onready var _leg_right: Node3D = $Visual/LegPivotRight
@onready var _arm_left: Node3D = $Visual/Upper/ArmPivotLeft
@onready var _arm_right: Node3D = $Visual/Upper/ArmPivotRight
@onready var _head: Node3D = $Visual/Upper/HeadPivot
@onready var _tool_prop: Node3D = $Visual/Upper/ArmPivotRight/ToolProp

## 步态相位（弧度）—— 累加量，不是时间，所以步频变化时不会"跳帧"
var _stride: float = 0.0
## 待机呼吸相位
var _breath: float = 0.0
## 0～1 的步态权重：移动时趋近 move_ratio，停下时趋近 0
var _gait: float = 0.0
## 手里工具的材质缓存（键 = 材质名）
var _prop_materials: Dictionary[String, StandardMaterial3D] = {}


func _ready() -> void:
	add_to_group("player")
	if _tool_prop != null:
		_tool_prop.rotation.x = TOOL_PROP_TILT
	EventBus.slot_selected.connect(_on_slot_selected)
	_rebuild_tool_prop()


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_apply_movement(delta)
	_animate_visual(delta)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta


func _apply_movement(delta: float) -> void:
	# move_back 作为"负向"，这样 W 永远得到 +1
	var forward_input: float = Input.get_axis("move_back", "move_forward")
	var strafe_input: float = Input.get_axis("move_left", "move_right")

	var yaw: float = deg_to_rad(camera_yaw_degrees)
	var forward: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))

	var direction: Vector3 = right * strafe_input + forward * forward_input
	var moving: bool = direction.length_squared() > 0.001
	if moving:
		direction = direction.normalized()

	is_running = moving and Input.is_action_pressed("run")
	var speed: float = RUN_SPEED if is_running else WALK_SPEED

	if moving:
		velocity.x = move_toward(velocity.x, direction.x * speed, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, ACCELERATION * delta)
		# ★ 局部 −Z 是 Godot 的"正前方"，所以取反 —— 见文件头「关键手感 2」
		var target_yaw: float = atan2(-direction.x, -direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, TURN_SPEED * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0.0, FRICTION * delta)

	# 用**实际**速度算强度，这样撞墙时摆动会自然停下（而不是原地踏步）
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	move_ratio = clampf(horizontal_speed / WALK_SPEED, 0.0, 1.0)
	run_ratio = clampf(
		(horizontal_speed - WALK_SPEED) / maxf(0.01, RUN_SPEED - WALK_SPEED),
		0.0, 1.0,
	)

	move_and_slide()


## 走路动画。每帧只改旋转与一个小位移，成本极低，
## 但"站着滑行"的廉价感会立刻消失。
func _animate_visual(delta: float) -> void:
	# 步态权重平滑过渡：起步时逐渐迈开、停步时逐渐收住
	_gait = move_toward(_gait, move_ratio, GAIT_BLEND_SPEED * delta)

	# 相位按**周期数**累加，这样步频变化时相位是连续的，不会跳一下
	var cycles_per_second: float = lerpf(STRIDE_WALK, STRIDE_RUN, run_ratio)
	_stride += delta * cycles_per_second * TAU
	_breath += delta * BREATH_FREQUENCY * TAU

	var swing: float = sin(_stride)
	var amount: float = _gait
	var leg_angle: float = swing * LEG_SWING * (1.0 + RUN_SWING_BOOST * run_ratio) * amount
	var arm_angle: float = swing * ARM_SWING * amount

	# ── 四肢：左右腿反相；同侧手臂与腿**反相**（左腿前 → 左臂后）──
	_leg_left.rotation.x = leg_angle
	_leg_right.rotation.x = -leg_angle
	_arm_left.rotation.x = -arm_angle
	_arm_right.rotation.x = arm_angle
	# 手臂往外张开（左右符号相反才叫"往外"），摆得越开张得越多，免得插进躯干
	var spread: float = ARM_SPREAD + absf(swing) * 0.06 * amount
	_arm_left.rotation.z = -spread
	_arm_right.rotation.z = spread

	# ── 身体：一个周期里起伏两次（absf(sin) 正好是双倍频率）+ 左右侧倾 ──
	var bob: float = absf(sin(_stride)) * BOB_HEIGHT * amount
	# 站着时用呼吸补一点微动 —— 完全静止的角色看起来像贴图
	var breathe: float = sin(_breath) * BREATH_AMPLITUDE * (1.0 - amount)
	_visual.position.y = bob + breathe
	_visual.rotation.z = sin(_stride) * BODY_ROLL * amount

	# ── 上身前倾：跑起来前倾更多 ──
	#    注意是**负角**：Godot 里绕 +X 正转会让人往后倒（局部 −Z 才是前方）
	var lean: float = -lerpf(LEAN_WALK, LEAN_RUN, run_ratio) * amount
	_upper.rotation.x = lean

	# ── 头轻轻反向摆：头在动、而不是整个身体在漂 ──
	_head.rotation.z = -sin(_stride) * HEAD_SWAY * amount
	# 躯干前倾时头往回抬一半 —— 人跑步时头是抬着的
	_head.rotation.x = -lean * 0.5


## 供其他系统查询：玩家当前朝向的平坦前向量（Godot 约定：局部 −Z）。
func facing_direction() -> Vector3:
	return Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))


# ── 手里那把工具 ─────────────────────────────────────────

func _on_slot_selected(_slot: int) -> void:
	_rebuild_tool_prop()


## 让"我现在拿着什么"在 3D 世界里直接看得见。
##
## 【为什么要做这个】快捷栏高亮只说明"第几格"。
##   玩家得把视线从农田移到屏幕底部才能确认拿的是锄头还是水壶；
##   把工具举在手上，视线不用离开农田。
##
## 【为什么每换一次就重建，而不是准备三套模型来回切显隐】
##   三件工具加起来才 6 个 BoxMesh。重建的代码量比维护
##   "三套场景 + 显隐切换 + 初始化顺序"低得多，也不会漏掉
##   "忘了把上一把隐藏"这类只在切换时才暴露的 bug。
func _rebuild_tool_prop() -> void:
	if _tool_prop == null:
		return
	for child: Node in _tool_prop.get_children():
		_tool_prop.remove_child(child)
		child.queue_free()

	var tool: ToolData = GameManager.selected_tool()
	if tool == null:
		# 手上是种子/空位 → 不显示工具
		_tool_prop.visible = false
		return
	_tool_prop.visible = true

	var wood: StandardMaterial3D = _prop_material("wood", Color(0.55, 0.37, 0.19), 0.85)
	var steel: StandardMaterial3D = _prop_material("steel", Color(0.80, 0.83, 0.88), 0.45)
	var tin: StandardMaterial3D = _prop_material("tin", Color(0.46, 0.70, 0.88), 0.40)

	match tool.id:
		ToolDatabase.HOE:
			_prop_box("Shaft", Vector3(0.05, 0.86, 0.05), Vector3(0.0, 0.32, 0.0), wood)
			_prop_box("Blade", Vector3(0.26, 0.07, 0.12), Vector3(0.09, 0.72, 0.0), steel)
		ToolDatabase.CAN:
			_prop_box("Body", Vector3(0.20, 0.24, 0.16), Vector3(0.0, 0.13, 0.0), tin)
			_prop_box("Spout", Vector3(0.32, 0.05, 0.05), Vector3(0.14, 0.24, 0.0), tin)
		ToolDatabase.SICKLE:
			_prop_box("Shaft", Vector3(0.05, 0.30, 0.05), Vector3(0.0, 0.12, 0.0), wood)
			_prop_box("Blade", Vector3(0.06, 0.30, 0.09), Vector3(0.0, 0.38, -0.11), steel)


func _prop_box(
	prop_name: String,
	box_size: Vector3,
	at: Vector3,
	material: StandardMaterial3D,
) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = box_size

	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = prop_name
	node.mesh = mesh
	node.position = at
	node.material_override = material
	# 关掉投影：手上这根小棒子在太阳下会在地上拖出一条会动的黑影，
	# 反而比"没有影子"更出戏。
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tool_prop.add_child(node)


func _prop_material(key: String, color: Color, roughness: float) -> StandardMaterial3D:
	if _prop_materials.has(key):
		return _prop_materials[key]
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	_prop_materials[key] = material
	return material
