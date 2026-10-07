class_name FarmView
extends Node3D
## 把「鼠标点击」翻译成「农场格位」，并把 FarmGrid 的状态画出来。
##
## 【层级】L4 表现层 —— 不含任何游戏规则，只做「翻译 + 绘制」。
##
## 【关键技术点 · 必读】鼠标拾取格子的正解是 `Plane.intersects_ray()`，
##   而不是射线查询物理世界。农田是一个水平面，数学求交**更快、更稳**，
##   而且完全不需要给每个格子挂碰撞体（见 DESIGN.md §5.4）。
##
## 【M0 说明】土壤与作物用**代码生成的简易网格**渲染，不依赖任何外部素材。
##   M1 会换成 GridMap + MeshLibrary（真实素材），届时只需要替换
##   `_ensure_soil()` / `_ensure_crop_node()` 两处，拾取与状态同步逻辑完全不动。

## 每格边长（米）。与 GridMap 的 cell_size 保持一致。
const TILE_SIZE: float = 1.0
## 农场左下角的世界坐标
const FARM_ORIGIN: Vector3 = Vector3(-8.0, 0.0, -8.0)
## 农场尺寸（格）
const FIELD_SIZE: Vector2i = Vector2i(16, 16)
## 无效格位的哨兵值
const NO_CELL: Vector2i = Vector2i(-9999, -9999)

const SOIL_HEIGHT: float = 0.08
const CROP_MESH_HEIGHT: float = 1.0

@onready var soil_root: Node3D = $Soil
@onready var crops_root: Node3D = $Crops
@onready var highlight: MeshInstance3D = $Highlight
@onready var ground: MeshInstance3D = $Ground
@onready var field_patch: MeshInstance3D = $FieldPatch

var _hover_cell: Vector2i = NO_CELL
## Vector2i → MeshInstance3D（土壤）。用类型化字典，取出即 MeshInstance3D 而非 Variant。
var _soil_nodes: Dictionary[Vector2i, MeshInstance3D] = {}
## Vector2i → Node3D（作物枢轴）
var _crop_nodes: Dictionary[Vector2i, Node3D] = {}

var _soil_dry: StandardMaterial3D
var _soil_wet: StandardMaterial3D
var _crop_material: StandardMaterial3D
var _highlight_material: StandardMaterial3D
var _crop_mesh: CylinderMesh
var _soil_mesh: BoxMesh
## 作物材质缓存，键是 "<crop_id>" 或 "<crop_id>|ripe"
var _crop_materials: Dictionary[String, StandardMaterial3D] = {}


func _ready() -> void:
	add_to_group("farm_view")
	_build_materials()
	_apply_ground_materials()
	EventBus.tile_changed.connect(_on_tile_changed)
	highlight.visible = false
	refresh_all()

	# 启动横幅 —— 同时也是"场景确实加载了"的证据
	print("[Star Game] M0 启动 · 引擎 %s · 农场 %d×%d 格 · %s" % [
		Engine.get_version_info().get("string", "unknown"),
		FIELD_SIZE.x,
		FIELD_SIZE.y,
		"左键操作 / Q·E 转视角 / 滚轮缩放 / 1-9 换种子 / F10 过夜 / F5 存档 / F9 读档",
	])


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("use_tool"):
		return
	var cell: Vector2i = pick_cell()
	if cell == NO_CELL:
		return
	var message: String = GameManager.use_tool(cell)
	EventBus.toast.emit(message)
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var cell: Vector2i = pick_cell()
	if cell != _hover_cell:
		_hover_cell = cell
		_update_highlight()


# ── 坐标换算 ─────────────────────────────────────────────

func world_to_cell(world: Vector3) -> Vector2i:
	var local: Vector3 = world - FARM_ORIGIN
	return Vector2i(floori(local.x / TILE_SIZE), floori(local.z / TILE_SIZE))


func cell_to_world(cell: Vector2i) -> Vector3:
	return FARM_ORIGIN + Vector3(
		(float(cell.x) + 0.5) * TILE_SIZE,
		0.0,
		(float(cell.y) + 0.5) * TILE_SIZE,
	)


func hovered_cell() -> Vector2i:
	return _hover_cell


# ── 拾取 ─────────────────────────────────────────────────

## 鼠标指向的农场格位。
## 没指到地面、或指到农场范围外时返回 NO_CELL。
func pick_cell() -> Vector2i:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return NO_CELL

	var mouse: Vector2 = get_viewport().get_mouse_position()
	var ray_from: Vector3 = camera.project_ray_origin(mouse)
	var ray_dir: Vector3 = camera.project_ray_normal(mouse)

	# ★ 农田是水平面，用数学求交，不查物理世界（见 DESIGN.md §5.4）
	var ground: Plane = Plane(Vector3.UP, 0.0)
	var hit: Variant = ground.intersects_ray(ray_from, ray_dir)
	if not (hit is Vector3):
		return NO_CELL

	var cell: Vector2i = world_to_cell(VariantUtil.to_vector3(hit))
	if not GameManager.farm.in_bounds(cell):
		return NO_CELL
	return cell


# ── 刷新 ─────────────────────────────────────────────────

## 全量重建（读档、进入新季节、调试用）。
func refresh_all() -> void:
	for key: Vector2i in _soil_nodes:
		var node: MeshInstance3D = _soil_nodes[key]
		if is_instance_valid(node):
			node.queue_free()
	for key: Vector2i in _crop_nodes:
		var node: Node3D = _crop_nodes[key]
		if is_instance_valid(node):
			node.queue_free()
	_soil_nodes.clear()
	_crop_nodes.clear()

	for cell: Vector2i in GameManager.farm.all_cells():
		_update_tile(cell)


func _on_tile_changed(cell: Vector2i) -> void:
	_update_tile(cell)


func _update_tile(cell: Vector2i) -> void:
	var tile: FarmTile = GameManager.farm.peek(cell)
	_update_soil(cell, tile)
	_update_crop(cell, tile)


func _update_soil(cell: Vector2i, tile: FarmTile) -> void:
	var node: MeshInstance3D = _ensure_soil(cell)
	if tile == null or tile.state == FarmTile.State.UNTILLED:
		node.visible = false
		return
	node.visible = true
	node.material_override = _soil_wet if tile.state == FarmTile.State.WATERED else _soil_dry


func _update_crop(cell: Vector2i, tile: FarmTile) -> void:
	var pivot: Node3D = _ensure_crop_node(cell)

	if tile == null or not tile.has_crop():
		pivot.visible = false
		return

	var data: CropData = CropDatabase.get_crop(tile.crop_id)
	var mature_days: int = data.mature_days if data != null else 4
	var stage: int = CropGrowth.stage_index(tile.growth, mature_days)
	var scale_value: float = CropGrowth.stage_scale(stage)

	pivot.visible = true
	# 缩放整条枢轴 ⇒ 底面始终贴着地面（枢轴原点在地面，子网格抬高了半高）
	pivot.scale = Vector3(scale_value, scale_value, scale_value)

	var mesh_node: MeshInstance3D = pivot.get_child(0) as MeshInstance3D
	if mesh_node != null:
		var ripe: bool = data != null and data.is_mature(tile.growth)
		mesh_node.material_override = _crop_material_for(tile.crop_id, ripe)


func _ensure_soil(cell: Vector2i) -> MeshInstance3D:
	if _soil_nodes.has(cell):
		var existing: MeshInstance3D = _soil_nodes[cell]
		if is_instance_valid(existing):
			return existing

	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = _soil_mesh
	node.position = cell_to_world(cell) + Vector3(0.0, SOIL_HEIGHT * 0.5, 0.0)
	node.name = "Soil_%d_%d" % [cell.x, cell.y]
	soil_root.add_child(node)
	_soil_nodes[cell] = node
	return node


func _ensure_crop_node(cell: Vector2i) -> Node3D:
	if _crop_nodes.has(cell):
		var existing: Node3D = _crop_nodes[cell]
		if is_instance_valid(existing):
			return existing

	var pivot: Node3D = Node3D.new()
	pivot.name = "Crop_%d_%d" % [cell.x, cell.y]
	pivot.position = cell_to_world(cell)
	pivot.visible = false

	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	mesh_node.mesh = _crop_mesh
	mesh_node.material_override = _crop_material
	# 圆锥形作物的几何中心在高度一半处，抬高半高让底面贴地
	mesh_node.position = Vector3(0.0, CROP_MESH_HEIGHT * 0.5, 0.0)
	pivot.add_child(mesh_node)

	crops_root.add_child(pivot)
	_crop_nodes[cell] = pivot
	return pivot


func _update_highlight() -> void:
	if _hover_cell == NO_CELL:
		highlight.visible = false
		return
	highlight.visible = true
	highlight.position = cell_to_world(_hover_cell) + Vector3(0.0, SOIL_HEIGHT + 0.01, 0.0)
	highlight.material_override = _highlight_material


# ── 材质与网格（M0 占位：纯色，M1 换真实素材）────────────

func _build_materials() -> void:
	_soil_dry = StandardMaterial3D.new()
	_soil_dry.albedo_color = Color(0.45, 0.32, 0.22)
	_soil_dry.roughness = 0.95

	_soil_wet = StandardMaterial3D.new()
	_soil_wet.albedo_color = Color(0.24, 0.17, 0.12)
	_soil_wet.roughness = 0.35
	_soil_wet.metallic = 0.15

	_crop_material = StandardMaterial3D.new()
	_crop_material.albedo_color = Color(0.36, 0.66, 0.28)
	_crop_material.roughness = 0.8

	_highlight_material = StandardMaterial3D.new()
	_highlight_material.albedo_color = Color(1.0, 0.94, 0.55, 0.35)
	_highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_soil_mesh = BoxMesh.new()
	_soil_mesh.size = Vector3(TILE_SIZE * 0.94, SOIL_HEIGHT, TILE_SIZE * 0.94)

	_crop_mesh = CylinderMesh.new()
	_crop_mesh.top_radius = 0.0
	_crop_mesh.bottom_radius = 0.26
	_crop_mesh.height = CROP_MESH_HEIGHT
	_crop_mesh.radial_segments = 8


## 成熟作物用品种本色 + 微弱自发光，一眼能认出来。
##
## 【为什么不用同一个绿色】九种作物全长一个样，站远了分不出田里种的是什么。
##   品种颜色存在 CropData.icon_color（L1 数据层），UI 图标也复用同一个颜色。
func _crop_material_for(crop_id: String, ripe: bool) -> StandardMaterial3D:
	var key: String = crop_id + ("|ripe" if ripe else "")
	if _crop_materials.has(key):
		return _crop_materials[key]

	var data: CropData = CropDatabase.get_crop(crop_id)
	var base: Color = data.icon_color if data != null else Color(0.36, 0.66, 0.28)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	if ripe:
		mat.albedo_color = base
		mat.roughness = 0.55
		mat.emission_enabled = true
		mat.emission = base * 0.32
	else:
		# 生长中往植物绿靠一截 —— "还没熟"要能一眼看出来
		mat.albedo_color = base.lerp(Color(0.34, 0.62, 0.27), 0.55)
		mat.roughness = 0.85

	_crop_materials[key] = mat
	return mat


# ── 地面与农田范围 ───────────────────────────────────────

## 给地面和农田范围贴上程序化生成的贴图（零素材，见 ProcTextures）。
##
## 【为什么农田那一层是"透明网格"而不是"一整块土色"】
##   没开垦的地就该长得跟草地一样，网格只是告诉玩家「这一块能种」。
##   铺一整块土色会让人误以为地已经翻好了。
func _apply_ground_materials() -> void:
	var grass: StandardMaterial3D = StandardMaterial3D.new()
	grass.albedo_texture = ProcTextures.grass_tile()
	grass.uv1_scale = Vector3(50.0, 50.0, 1.0)
	grass.roughness = 0.95
	ground.material_override = grass

	var field: StandardMaterial3D = StandardMaterial3D.new()
	field.albedo_texture = ProcTextures.field_grid(FIELD_SIZE.x, 48)
	field.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	field.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	field_patch.material_override = field
