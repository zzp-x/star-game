class_name SunController
extends DirectionalLight3D
## 太阳 —— 由游戏时间驱动角度与颜色。
##
## 【层级】L4 表现层
## 【设计要点 · 值得记住】光照是「订阅者」，不是「被调用者」。
##   TimeManager 从不主动通知光照；是本节点自己订阅 `minute_tick` 后响应。
##   所以时间系统永远不需要知道场景里有一盏太阳（见 DESIGN.md §3.4）。
##
## 【3D 的加分项】太阳的弧线本身就是玩家的时钟 —— 2D 里只能靠 HUD 读时间。
##   黄昏暖橙 → 夜晚冷蓝，是免费拿到的时间感知。

## 正午高度角：春/夏高，秋/冬低（季节视觉差异的一半来自这里）
## 【注意】必须用 Array（字面量是常量表达式）；PackedFloat32Array(...) 不是，
## 写 `const X: PackedFloat32Array = PackedFloat32Array([...])` 会报
## "isn't a constant expression"。
const ELEVATION_BY_SEASON: Array[float] = [58.0, 68.0, 46.0, 32.0]
## 方位角扫过的范围（度）：从东边升起到西边落下
const AZIMUTH_START: float = -96.0
const AZIMUTH_END: float = 96.0

const DAYLIGHT_ENERGY: float = 1.15
const NIGHT_ENERGY: float = 0.16
const DAYLIGHT_COLOR: Color = Color(1.0, 0.97, 0.9)
const DUSK_COLOR: Color = Color(1.0, 0.72, 0.44)
const NIGHT_COLOR: Color = Color(0.55, 0.66, 0.92)

var _environment_node: WorldEnvironment = null
var _base_ambient: Color = Color(0.6, 0.65, 0.72)


func _ready() -> void:
	shadow_enabled = true
	# 让阴影跟随相机视锥，保证玩家附近永远有高质量阴影
	directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	directional_shadow_max_distance = 60.0

	_environment_node = get_tree().get_first_node_in_group("world_environment") as WorldEnvironment
	if _environment_node != null and _environment_node.environment != null:
		_base_ambient = _environment_node.environment.ambient_light_color

	EventBus.minute_tick.connect(_on_minute_tick)
	_refresh()


func _on_minute_tick(_total_minutes: int) -> void:
	_refresh()


func _refresh() -> void:
	var progress: float = TimeManager.normalized_day_progress()

	var azimuth: float = lerpf(AZIMUTH_START, AZIMUTH_END, progress)
	var max_elevation: float = ELEVATION_BY_SEASON[TimeManager.clock.season]
	# sin 曲线让太阳在中段最高、两端贴地
	var elevation: float = maxf(2.0, sin(progress * PI) * max_elevation)

	rotation_degrees = Vector3(-elevation, azimuth, 0.0)

	var warmth: float = clampf(1.0 - sin(progress * PI), 0.0, 1.0)
	var night: bool = TimeManager.is_night()

	var color: Color = DUSK_COLOR.lerp(DAYLIGHT_COLOR, 1.0 - warmth)
	if night:
		color = NIGHT_COLOR
	light_color = color

	light_energy = lerpf(DAYLIGHT_ENERGY, NIGHT_ENERGY, warmth) if not night else NIGHT_ENERGY

	if _environment_node != null and _environment_node.environment != null:
		var env: Environment = _environment_node.environment
		env.ambient_light_color = _base_ambient.lerp(Color(0.28, 0.34, 0.52), warmth * 0.9)
		env.ambient_light_energy = lerpf(0.75, 0.25, warmth)
