class_name Player
extends CharacterBody3D
## 玩家控制器（3D）。
##
## 【层级】L4 表现层 —— 只做「输入采集 + 移动」，不含任何游戏规则。
## 【关键手感】移动方向是**相对相机**的：按 A 永远是"屏幕左"，
##   这样相机 90° 旋转之后操作逻辑完全不变（见 DESIGN.md §3.3 / §5.3）。
##
## 【3D 新手最容易踩的坑】Vector3 的 y 是"上"，不是"里"。
##   地面平面用 x/z，高度用 y。把 Vector3 当 Vector2 用会得到诡异的移动。

const WALK_SPEED: float = 4.5
const RUN_SPEED: float = 7.0
const ACCELERATION: float = 45.0
const FRICTION: float = 55.0
const GRAVITY: float = 24.0
const TURN_SPEED: float = 12.0

## 相机偏航角（度），由 CameraRig 每帧写入 —— 这是"相对相机移动"的基准。
var camera_yaw_degrees: float = 0.0
## 是否正在奔跑（跑步消耗体力，M1 接体力系统）
var is_running: bool = false


func _ready() -> void:
	add_to_group("player")


func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_apply_movement(delta)


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
		# 角色朝向移动方向（8 方向动画足够，不需要转身平滑动画）
		var target_yaw: float = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, TURN_SPEED * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0.0, FRICTION * delta)

	move_and_slide()


## 供其他系统查询：玩家当前朝向的平坦前向量。
func facing_direction() -> Vector3:
	return Vector3(sin(rotation.y), 0.0, cos(rotation.y))
