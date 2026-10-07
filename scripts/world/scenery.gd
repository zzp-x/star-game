class_name Scenery
extends Node3D
## 场景装饰物 —— 程序化生成的低多边形树、灌木、石头，以及农田围栏。
##
## 【层级】L4 表现层 —— 只负责"让场景不像一块空白画布"。
##
## 【为什么必须留出一圈空地 · 重要】
##   相机是固定斜俯视、站在玩家「后上方」约 14 米高处往下看。
##   任何长在「相机 → 玩家」这条视线上的高物件，都会挡住主角。
##   所以在原点周围 CLEAR_RADIUS 之内不放高于 1 米的装饰物。
##   这圈空地顺便就当成了农田的院子。
##
## 【为什么用固定种子】每次启动的树位置都一样 —— 方便截图对比、
##   也方便"这棵树挡住视野"这类问题被复现而不是随机出现。

const FIELD_HALF: float = 8.0
## 这个半径之内不放高物件（见文件头说明）
const CLEAR_RADIUS: float = 14.0
const OUTER_RADIUS: float = 46.0
## 围栏离农田边界多远（米）
const FENCE_OFFSET: float = 0.6
## 围栏在 +Z 侧留的门，半宽（米）—— 玩家从这里进田
const GATE_HALF: float = 1.5

const TREE_COUNT: int = 26
const BUSH_COUNT: int = 20
const ROCK_COUNT: int = 14

## 固定种子：位置每次一致（见文件头）
const SCATTER_SEED: int = 424242

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _trunk_mesh: CylinderMesh
var _leaf_mesh: SphereMesh
var _bush_mesh: SphereMesh
var _rock_mesh: SphereMesh
var _post_mesh: BoxMesh
var _rail_mesh: BoxMesh

var _wood_mat: StandardMaterial3D
var _trunk_mat: StandardMaterial3D
var _rock_mat: StandardMaterial3D
var _leaf_mats: Array[StandardMaterial3D] = []


func _ready() -> void:
	_rng.seed = SCATTER_SEED
	_build_meshes()
	_build_materials()
	_scatter_props()
	_build_fence()


# ── 网格与材质 ───────────────────────────────────────────

func _build_meshes() -> void:
	_trunk_mesh = CylinderMesh.new()
	_trunk_mesh.top_radius = 0.13
	_trunk_mesh.bottom_radius = 0.20
	_trunk_mesh.height = 2.0
	_trunk_mesh.radial_segments = 6
	_trunk_mesh.rings = 1

	# 段数刻意压低 —— 低多边形风格的"棱面感"就是这么来的
	_leaf_mesh = SphereMesh.new()
	_leaf_mesh.radius = 1.0
	_leaf_mesh.height = 2.0
	_leaf_mesh.radial_segments = 8
	_leaf_mesh.rings = 5

	_bush_mesh = SphereMesh.new()
	_bush_mesh.radius = 0.5
	_bush_mesh.height = 1.0
	_bush_mesh.radial_segments = 7
	_bush_mesh.rings = 4

	_rock_mesh = SphereMesh.new()
	_rock_mesh.radius = 0.5
	_rock_mesh.height = 1.0
	_rock_mesh.radial_segments = 5
	_rock_mesh.rings = 3

	_post_mesh = BoxMesh.new()
	_post_mesh.size = Vector3(0.14, 1.0, 0.14)

	_rail_mesh = BoxMesh.new()
	_rail_mesh.size = Vector3(1.0, 0.09, 0.07)


func _build_materials() -> void:
	_wood_mat = _mat(Color(0.47, 0.33, 0.20), 0.9)
	_trunk_mat = _mat(Color(0.34, 0.24, 0.15), 0.95)
	_rock_mat = _mat(Color(0.52, 0.52, 0.55), 0.85)

	# 三档树冠绿，随机挑一个 —— 整片树林立刻不再是同一块色板
	_leaf_mats.append(_mat(Color(0.24, 0.46, 0.22), 0.85))
	_leaf_mats.append(_mat(Color(0.31, 0.53, 0.24), 0.85))
	_leaf_mats.append(_mat(Color(0.20, 0.40, 0.20), 0.85))


func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


# ── 撒装饰物 ─────────────────────────────────────────────

func _scatter_props() -> void:
	for _i: int in TREE_COUNT:
		_place(_make_tree(), _rng.randf_range(0.75, 1.15))
	for _i: int in BUSH_COUNT:
		_place(_make_bush(), _rng.randf_range(0.8, 1.5))
	for _i: int in ROCK_COUNT:
		_place(_make_rock(), 1.0)


## 把节点放到环形空地上（半径 CLEAR_RADIUS~OUTER_RADIUS 之间）。
func _place(node: Node3D, scale_factor: float) -> void:
	var angle: float = _rng.randf_range(0.0, TAU)
	# 用 sqrt 使点在面积上均匀分布，否则会全挤在内圈
	var radius: float = sqrt(_rng.randf_range(CLEAR_RADIUS * CLEAR_RADIUS, OUTER_RADIUS * OUTER_RADIUS))
	node.position = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	node.rotation.y = _rng.randf_range(0.0, TAU)
	node.scale = Vector3(scale_factor, scale_factor, scale_factor)
	add_child(node)


func _make_tree() -> Node3D:
	var tree: Node3D = Node3D.new()
	tree.name = "Tree"
	var mat: StandardMaterial3D = _leaf_mats[_rng.randi_range(0, _leaf_mats.size() - 1)]

	var trunk: MeshInstance3D = MeshInstance3D.new()
	trunk.mesh = _trunk_mesh
	trunk.material_override = _trunk_mat
	trunk.position = Vector3(0.0, 1.0, 0.0)
	tree.add_child(trunk)

	# 2～3 团树冠往上堆，越往上越小 —— 低多边形树的标准做法
	var blobs: int = _rng.randi_range(2, 3)
	for i: int in blobs:
		var leaf: MeshInstance3D = MeshInstance3D.new()
		leaf.mesh = _leaf_mesh
		leaf.material_override = mat
		var r: float = _rng.randf_range(1.05, 1.35) * (1.0 - 0.20 * float(i))
		leaf.scale = Vector3(r, r * _rng.randf_range(0.78, 0.98), r)
		leaf.position = Vector3(
			_rng.randf_range(-0.22, 0.22),
			2.5 + float(i) * 0.72,
			_rng.randf_range(-0.22, 0.22),
		)
		tree.add_child(leaf)
	return tree


func _make_bush() -> Node3D:
	var bush: Node3D = Node3D.new()
	bush.name = "Bush"
	var mat: StandardMaterial3D = _leaf_mats[_rng.randi_range(0, _leaf_mats.size() - 1)]
	for i: int in 3:
		var leaf: MeshInstance3D = MeshInstance3D.new()
		leaf.mesh = _bush_mesh
		leaf.material_override = mat
		var r: float = _rng.randf_range(0.8, 1.15)
		leaf.scale = Vector3(r, r * 0.85, r)
		leaf.position = Vector3(
			_rng.randf_range(-0.32, 0.32),
			r * 0.4,
			_rng.randf_range(-0.32, 0.32),
		)
		bush.add_child(leaf)
	return bush


func _make_rock() -> Node3D:
	var rock: MeshInstance3D = MeshInstance3D.new()
	rock.name = "Rock"
	rock.mesh = _rock_mesh
	rock.material_override = _rock_mat
	var s: float = _rng.randf_range(0.55, 1.5)
	var sy: float = s * _rng.randf_range(0.45, 0.75)
	rock.scale = Vector3(s * _rng.randf_range(0.9, 1.35), sy, s * _rng.randf_range(0.9, 1.35))
	# 半埋进地里，才像"地上有块石头"而不是"浮着个球"
	rock.position.y = sy * 0.28
	rock.rotation.y = _rng.randf_range(0.0, TAU)
	return rock


# ── 围栏 ─────────────────────────────────────────────────

## 农田四周的木围栏，+Z 侧留一个门。
##
## 【为什么围栏要带碰撞体】围栏如果不能挡人，走过去就穿模，比没有更糟。
##   碰撞体做成 5 个长方体（南边拆成左右两段留门），而不是给每根柱子一个形状 ——
##   形状少、稳、也好排查。
func _build_fence() -> void:
	var o: float = FIELD_HALF + FENCE_OFFSET
	var posts: Array[Transform3D] = []
	var rails: Array[Transform3D] = []

	_build_side(posts, rails, Vector3(-o, 0.0, -o), Vector3(o, 0.0, -o), false)  # 北
	_build_side(posts, rails, Vector3(-o, 0.0, o), Vector3(o, 0.0, o), true)    # 南（留门）
	_build_side(posts, rails, Vector3(-o, 0.0, -o), Vector3(-o, 0.0, o), false)  # 西
	_build_side(posts, rails, Vector3(o, 0.0, -o), Vector3(o, 0.0, o), false)    # 东

	add_child(_make_multimesh(_post_mesh, _wood_mat, posts, "FencePosts"))
	add_child(_make_multimesh(_rail_mesh, _wood_mat, rails, "FenceRails"))
	_build_fence_collision(o)


func _build_side(
	posts: Array[Transform3D],
	rails: Array[Transform3D],
	a: Vector3,
	b: Vector3,
	gated: bool,
) -> void:
	var steps: int = int((b - a).length())
	for i: int in range(steps + 1):
		var p: Vector3 = a.lerp(b, float(i) / float(steps))
		if gated and absf(p.x) <= GATE_HALF:
			continue
		posts.append(Transform3D(Basis(), Vector3(p.x, 0.5, p.z)))

	for i: int in range(steps):
		var p0: Vector3 = a.lerp(b, float(i) / float(steps))
		var p1: Vector3 = a.lerp(b, float(i + 1) / float(steps))
		if gated and absf((p0.x + p1.x) * 0.5) <= GATE_HALF:
			continue
		rails.append(_rail_transform(p0, p1, 0.32))
		rails.append(_rail_transform(p0, p1, 0.70))


## 横杆网格沿局部 X 轴长 1 米：先把 X 轴转到 p0→p1 方向，再按长度缩放。
func _rail_transform(p0: Vector3, p1: Vector3, height: float) -> Transform3D:
	var mid: Vector3 = (p0 + p1) * 0.5
	var dir: Vector3 = p1 - p0
	var x_axis: Vector3 = dir.normalized()
	var z_axis: Vector3 = x_axis.cross(Vector3.UP).normalized()
	var y_axis: Vector3 = z_axis.cross(x_axis)
	var basis: Basis = Basis(x_axis, y_axis, z_axis).scaled(Vector3(dir.length(), 1.0, 1.0))
	return Transform3D(basis, Vector3(mid.x, height, mid.z))


func _make_multimesh(
	mesh: Mesh,
	mat: Material,
	transforms: Array[Transform3D],
	node_name: String,
) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i: int in transforms.size():
		mm.set_instance_transform(i, transforms[i])

	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = mm
	node.material_override = mat
	return node


## 5 个长方体当围栏碰撞：北 / 西 / 东各一段，南边左右两段（中间是门）。
func _build_fence_collision(o: float) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "FenceCollision"
	body.collision_layer = 1
	body.collision_mask = 0  # 只挡人，不参与别的查询

	var thickness: float = 0.25
	var half_extent: float = o + thickness * 0.5

	var spans: Array[Array] = [
		# [中心 x, 中心 z, 尺寸 x, 尺寸 z]
		[0.0, -o, half_extent * 2.0, thickness],                                   # 北
		[-half_extent, 0.0, thickness, half_extent * 2.0],                          # 西
		[half_extent, 0.0, thickness, half_extent * 2.0],                           # 东
	]
	# 南边拆成左右两段，中间留门
	var south_len: float = o - GATE_HALF
	var south_center: float = GATE_HALF + south_len * 0.5
	spans.append([-south_center, o, south_len, thickness])
	spans.append([south_center, o, south_len, thickness])

	for span: Array in spans:
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(
			VariantUtil.to_float(span[2]),
			1.0,
			VariantUtil.to_float(span[3]),
		)
		var shape_node: CollisionShape3D = CollisionShape3D.new()
		shape_node.shape = shape
		shape_node.position = Vector3(
			VariantUtil.to_float(span[0]),
			0.5,
			VariantUtil.to_float(span[1]),
		)
		body.add_child(shape_node)

	add_child(body)
