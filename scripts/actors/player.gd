class_name Player
extends CharacterBody3D
## 玩家控制器（3D）。
##
## 【层级】L4 表现层 —— 只做「输入采集 + 移动 + 走路摆动」，不含任何游戏规则。
##
## 【关键手感 1 · 相对相机移动】移动方向是**相对相机**的：按 A 永远是"屏幕左"，
##   这样相机 90° 旋转之后操作逻辑完全不变（见 DESIGN.md §3.3 / §5.3）。
##
## 【关键手感 2 · 朝向约定】Godot 里节点的"正前方"是局部 **−Z**（不是 +Z）。
##   所以朝向要用 atan2(−dir.x, −dir.z)，否则角色会**倒着走** ——
##   脸在 −Z 却没转过去，看起来像后退。这个 bug 很隐蔽，因为"能走"看不出来。
##
## 【3D 新手最容易踩的坑】Vector3 的 y 是"上"，不是"里"。
##   地面平面用 x/z，高度用 y。把 Vector3 当 Vector2 用会得到诡异的移动。

const WALK_SPEED: float = 4.2
const RUN_SPEED: float = 6.6
const ACCELERATION: float = 45.0
const FRICTION: float = 55.0
const GRAVITY: float = 24.0
const TURN_SPEED: float = 12.0

## 走路上下摆动的幅度（米）与频率
const BOB_HEIGHT: float = 0.055
const BOB_FREQUENCY: float = 9.0
## 摆动进入/退出的平滑速度
const BOB_BLEND_SPEED: float = 9.0

## 相机偏航角（度），由 CameraRig 每帧写入 —— 这是"相对相机移动"的基准。
var camera_yaw_degrees: float = 0.0
## 是否正在奔跑（跑步消耗体力，M1 接体力系统）
var is_running: bool = false
## 0～1 的移动强度，供动画与音效使用（0 = 站着）
var move_ratio: float = 0.0

@onready var _visual: Node3D = $Visual

var _bob_phase: float = 0.0


func _ready() -> void:
	add_to_group("player")


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

	# move_ratio 用实际速度算，这样撞墙时摆动会自然停下
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	move_ratio = clampf(horizontal_speed / WALK_SPEED, 0.0, 1.0)

	move_and_slide()


## 走路时上下轻摆 + 轻微左右摇 —— 成本极低，但"站立滑行"的廉价感立刻消失。
func _animate_visual(delta: float) -> void:
	if _visual == null:
		return
	_bob_phase += delta * BOB_FREQUENCY
	var amount: float = absf(sin(_bob_phase)) * move_ratio
	_visual.position.y = amount * BOB_HEIGHT
	_visual.rotation.z = sin(_bob_phase * 0.5) * 0.045 * move_ratio


## 供其他系统查询：玩家当前朝向的平坦前向量（Godot 约定：局部 −Z）。
func facing_direction() -> Vector3:
	return Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
