class_name CameraRig
extends Camera3D
## 固定斜俯视相机 —— 3D 版最省事的相机方案（见 DESIGN.md §3.3）。
##
## 【为什么这样设计】
##   · 俯角锁死 −52° ⇒ **不需要防穿模**（第三人称最麻烦的一块直接消失）
##   · 只能 90° 分步旋转 ⇒ 格子与屏幕保持轴对齐，鼠标点选与建造对齐都直观
##   · 边缘平移有上限 ⇒ 玩家永远不会"找不到自己在哪"
##   · 低 FOV（40°）⇒ 削弱边缘透视变形，接近正交的整洁感，又保留纵深感
##
## 【层级】L4 表现层 —— 只负责"看见"，不含任何游戏规则。

const ROTATE_LERP: float = 10.0
const FOLLOW_LERP: float = 8.0
## 鼠标进入屏幕边缘多少像素内触发平移
const EDGE_MARGIN_PX: float = 20.0
const EDGE_PAN_SPEED: float = 7.0
## 平移偏移回到 0 的速度（"松手回到玩家"）
const PAN_RETURN_SPEED: float = 5.0
## 边缘平移相对玩家的最大偏移，防止看不见自己
const MAX_PAN_DISTANCE: float = 9.0

@export var pitch_degrees: float = -52.0
@export var fov_degrees: float = 40.0
@export var zoom_distance: float = 18.0
@export var min_zoom_distance: float = 10.0
@export var max_zoom_distance: float = 28.0
## 关闭后可用 set_process(false) 自由控制（过场、对话镜头会用到）
@export var edge_pan_enabled: bool = true

var target_yaw_degrees: float = 0.0

var _current_yaw_degrees: float = 0.0
var _pan_offset: Vector3 = Vector3.ZERO
var _target: Node3D = null
var _initialized: bool = false


func _ready() -> void:
	fov = fov_degrees
	_current_yaw_degrees = target_yaw_degrees


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_rotate_left"):
		target_yaw_degrees -= 90.0
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera_rotate_right"):
		target_yaw_degrees += 90.0
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_distance = clampf(zoom_distance - 1.5, min_zoom_distance, max_zoom_distance)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_distance = clampf(zoom_distance + 1.5, min_zoom_distance, max_zoom_distance)


func _process(delta: float) -> void:
	if _target == null:
		_target = get_tree().get_first_node_in_group("player") as Node3D
		if _target == null:
			return

	_rotate_toward_target(delta)
	_update_edge_pan(delta)
	_apply_transform(delta)

	# 把偏航告诉玩家，这是"按 A 永远往屏幕左走"的基准
	if _target is Player:
		(_target as Player).camera_yaw_degrees = _current_yaw_degrees


## 角度插值要走「最短路径」，否则从 270° 转到 0° 会绕一大圈。
func _rotate_toward_target(delta: float) -> void:
	var diff: float = fmod(target_yaw_degrees - _current_yaw_degrees + 540.0, 360.0) - 180.0
	_current_yaw_degrees += diff * minf(1.0, ROTATE_LERP * delta)


func _update_edge_pan(delta: float) -> void:
	if not edge_pan_enabled or _target == null:
		return

	var viewport: Viewport = get_viewport()
	var size: Vector2 = viewport.get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var mouse: Vector2 = viewport.get_mouse_position()

	var input: Vector2 = Vector2.ZERO
	if mouse.x <= EDGE_MARGIN_PX:
		input.x = -1.0
	elif mouse.x >= size.x - EDGE_MARGIN_PX:
		input.x = 1.0
	if mouse.y <= EDGE_MARGIN_PX:
		input.y = 1.0
	elif mouse.y >= size.y - EDGE_MARGIN_PX:
		input.y = -1.0

	if input == Vector2.ZERO:
		_pan_offset = _pan_offset.move_toward(Vector3.ZERO, PAN_RETURN_SPEED * delta * MAX_PAN_DISTANCE * 0.5)
		return

	# 把屏幕方向转成世界方向（相对相机偏航）
	var yaw: float = deg_to_rad(_current_yaw_degrees)
	var right: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
	var forward: Vector3 = Vector3(-sin(yaw), 0.0, -cos(yaw))
	var direction: Vector3 = (right * input.x + forward * input.y).normalized()

	_pan_offset += direction * EDGE_PAN_SPEED * delta
	if _pan_offset.length() > MAX_PAN_DISTANCE:
		_pan_offset = _pan_offset.normalized() * MAX_PAN_DISTANCE


func _apply_transform(delta: float) -> void:
	var pivot: Vector3 = _target.global_position + Vector3(0.0, 1.0, 0.0) + _pan_offset

	var yaw: float = deg_to_rad(_current_yaw_degrees)
	var pitch: float = deg_to_rad(pitch_degrees)
	# 相机在玩家的「后上方」：pitch 为负 ⇒ -sin(pitch) 为正 ⇒ y 向上
	var offset: Vector3 = Vector3(
		sin(yaw) * cos(pitch),
		-sin(pitch),
		cos(yaw) * cos(pitch),
	) * zoom_distance

	var desired: Vector3 = pivot + offset
	# 首帧直接就位，避免从原点飞过去
	global_position = desired if not _initialized else global_position.lerp(desired, minf(1.0, FOLLOW_LERP * delta))
	_initialized = true

	look_at(pivot, Vector3.UP)


## 当前相机偏航（度），0 / 90 / 180 / 270。
func current_yaw_degrees() -> float:
	return fmod(_current_yaw_degrees + 720.0, 360.0)
