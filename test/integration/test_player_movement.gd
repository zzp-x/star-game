extends GutTest
## 集成测试：玩家「能站住、能动」这两条最基本的体验底线。
##
## 【为什么必须有这类测试】
## M0 交付后用户实际运行反馈「前进后退左右都控制不了」。
## 根因是 farm.tscn 的 Ground 只有 MeshInstance3D、**没有碰撞体** ——
## 玩家脚下是空的，一直往下掉，相机跟着一起坠，看起来就像"按键没反应"。
##
## 这个 bug 之前所有检查都漏掉了：
##   · 脚本解析 → 通过（场景语法没问题）
##   · 单元测试 → 通过（规则都写在 core/，跟物理无关）
##   · headless 冒烟 → 通过（进程正常启动、正常退出）
## 它只在「玩家 + 物理 + 地面」三者同时存在时才暴露。
##
## 所以这里直接实例化真实场景、模拟真实输入，断言"真的位移了"。
## 以后任何人把地面碰撞改坏，CI 立刻红。

const FARM_SCENE: String = "res://scenes/world/farm.tscn"
## 首次落地所需帧数（1.5 秒，足够从出生高度掉下来并稳定）
const SETTLE_FRAMES: int = 90
## 施加移动输入持续帧数
const MOVE_FRAMES: int = 40

const ACTIONS: Array[String] = ["move_forward", "move_back", "move_left", "move_right", "run"]

var _root: Node3D = null
var _player: Player = null


func before_each() -> void:
	var packed: PackedScene = load(FARM_SCENE)
	_root = packed.instantiate() as Node3D
	add_child(_root)
	_player = _root.get_node_or_null("Player") as Player
	assert_not_null(_player, "场景里应该有一个 Player 节点")


func after_each() -> void:
	for action: String in ACTIONS:
		Input.action_release(action)
	if _root != null:
		_root.queue_free()
	_root = null
	_player = null


## 推进若干个物理帧 —— 移动写在 _physics_process 里，必须让物理真的跑起来。
func _step(frames: int) -> void:
	for _i: int in frames:
		await get_tree().physics_frame


func _horizontal_distance(from: Vector3, to: Vector3) -> float:
	return Vector2(to.x - from.x, to.z - from.z).length()


# ── 结构：地面必须带碰撞体 ───────────────────────────────

func test_ground_has_collision_body() -> void:
	var body: Node = _root.get_node_or_null("GroundCollision")
	assert_not_null(
		body,
		"地面必须有一个 StaticBody3D —— 只有 MeshInstance3D 的话玩家会一直往下掉",
	)
	assert_true(body is StaticBody3D, "GroundCollision 应该是 StaticBody3D")

	var shape_node: Node = body.get_node_or_null("CollisionShape3D")
	assert_not_null(shape_node, "StaticBody3D 下面必须挂 CollisionShape3D")
	assert_not_null((shape_node as CollisionShape3D).shape, "CollisionShape3D 必须有 shape 资源")


# ── 落地 ─────────────────────────────────────────────────

func test_player_stands_on_ground() -> void:
	await _step(SETTLE_FRAMES)

	assert_true(_player.is_on_floor(), "玩家必须站在地面上（is_on_floor 为假就是地面缺碰撞体）")
	assert_almost_eq(_player.global_position.y, 0.0, 0.1, "落地高度应接近 0")


func test_player_does_not_sink_over_time() -> void:
	await _step(SETTLE_FRAMES)
	var y_after_landing: float = _player.global_position.y

	await _step(SETTLE_FRAMES)

	assert_almost_eq(_player.global_position.y, y_after_landing, 0.05, "站着不动不应该继续下沉")


## 反证用例（对照组）：把地面碰撞体拿掉，玩家必须掉下去。
##
## 【为什么值得留着】上面那些"玩家站得住"的断言，只有在**确实会失败**时才有意义。
## 这条用例把当初的故障（地面只有 MeshInstance3D）复现出来，
## 证明整套测试真的能抓住它 —— 而不是碰巧通过。
func test_without_ground_collision_the_player_falls() -> void:
	var body: Node = _root.get_node_or_null("GroundCollision")
	assert_not_null(body, "先确认碰撞体存在，否则这条反证没有意义")
	body.queue_free()
	await _step(2)

	await _step(SETTLE_FRAMES)

	assert_false(_player.is_on_floor(), "没有地面碰撞体时，玩家不应该判定为站在地上")
	assert_lt(
		_player.global_position.y,
		-2.0,
		"没有地面碰撞体时，玩家应该一直往下掉（实际 y = %.2f）" % _player.global_position.y,
	)


# ── 移动：四个方向都要真的动 ─────────────────────────────

## 相机偏航为 0 时（M0 默认），W 应该往 −Z 走 —— 逐条锁死。
func test_each_direction_moves_player_the_right_way() -> void:
	await _step(SETTLE_FRAMES)

	var cases: Array[Dictionary] = [
		{"action": "move_forward", "axis": Vector3(0.0, 0.0, -1.0), "name": "W 前"},
		{"action": "move_back", "axis": Vector3(0.0, 0.0, 1.0), "name": "S 后"},
		{"action": "move_left", "axis": Vector3(-1.0, 0.0, 0.0), "name": "A 左"},
		{"action": "move_right", "axis": Vector3(1.0, 0.0, 0.0), "name": "D 右"},
	]

	for case: Dictionary in cases:
		var before: Vector3 = _player.global_position
		var action: String = VariantUtil.dict_str(case, "action")
		var axis: Vector3 = VariantUtil.to_vector3(case.get("axis"))

		Input.action_press(action)
		await _step(MOVE_FRAMES)
		Input.action_release(action)

		var delta: Vector3 = _player.global_position - before
		var along: float = delta.x * axis.x + delta.z * axis.z
		assert_gt(
			along,
			0.5,
			"%s 应该朝 %s 方向至少移动 0.5 米（实际位移 %s）" % [VariantUtil.dict_str(case, "name"), axis, delta],
		)


func test_player_stands_still_without_input() -> void:
	await _step(SETTLE_FRAMES)
	var before: Vector3 = _player.global_position

	await _step(MOVE_FRAMES)

	assert_lt(_horizontal_distance(before, _player.global_position), 0.05, "没有输入时不应该自己移动")


func test_run_is_faster_than_walk() -> void:
	await _step(SETTLE_FRAMES)

	var walk_before: Vector3 = _player.global_position
	Input.action_press("move_forward")
	await _step(MOVE_FRAMES)
	Input.action_release("move_forward")
	var walked: float = _horizontal_distance(walk_before, _player.global_position)

	var run_before: Vector3 = _player.global_position
	Input.action_press("move_forward")
	Input.action_press("run")
	await _step(MOVE_FRAMES)
	Input.action_release("move_forward")
	Input.action_release("run")
	var ran: float = _horizontal_distance(run_before, _player.global_position)

	assert_gt(ran, walked * 1.1, "按住 Shift 跑应该明显比走快（走 %.2f 米 / 跑 %.2f 米）" % [walked, ran])


# ── 朝向：模型必须朝着移动方向（不是倒着走）──────────────

func test_player_visual_faces_its_movement_direction() -> void:
	await _step(SETTLE_FRAMES)

	Input.action_press("move_right")
	await _step(MOVE_FRAMES)
	Input.action_release("move_right")

	# Godot 约定：局部 −Z 是"正前方"，也是模型脸的朝向。
	# 写成 atan2(dir.x, dir.z) 会让局部的 +Z 对齐移动方向 ——
	# 于是脸（在 −Z）一直背对前进方向，角色看起来在倒着走。
	var visual_forward: Vector3 = -_player.global_transform.basis.z
	assert_gt(
		visual_forward.dot(Vector3.RIGHT),
		0.9,
		"模型的脸必须朝着移动方向，不能倒着走（实际朝向 %s）" % visual_forward,
	)
	assert_gt(
		_player.facing_direction().dot(Vector3.RIGHT),
		0.9,
		"facing_direction() 必须和模型实际朝向一致",
	)
