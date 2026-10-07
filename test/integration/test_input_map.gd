extends GutTest
## 集成测试：验证 `project.godot` 的输入映射表与代码真的对得上。
##
## 【为什么需要这类测试】
## 输入映射是一份「配置」，代码是另一份「事实」。两者一旦脱节，症状是
## 「照着映射表改了键 / 加了新作物，游戏里毫无反应」—— 极难排查，
## 因为代码能跑、测试全绿、日志无错，只是你按的那个键没人听。
##
## 这个项目就真的出现过两次：
##   ① 映射表里只有 `tool_1`~`tool_5`，而代码直接用 `physical_keycode - KEY_1`
##      自己算 —— 映射表成了摆设，后来快捷栏扩到 9 格时 `tool_6`~`tool_9` 根本不存在。
##   ② 快捷栏扩到 12 格（3 工具 + 9 种子）后，`tool_10`~`tool_12` 又一次成为缺口。
## 本文件锁死「动作存在」+「动作能对上格位」+「格位顺序 = 数据表顺序」三件事。

## 12 格对应的 12 个按键。1~9 之后必须用 0 / - / =（星露谷的做法），
## 因为数字键只有 1~9 九个。
const EXPECTED_SLOT_KEYS: Array[Key] = [
	KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6,
	KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS, KEY_EQUAL,
]


func before_each() -> void:
	GameManager.use_slot(0)


## 造一个"按下某键"的事件。
## 同时填 keycode 与 physical_keycode：Godot 的动作匹配会先看 keycode、
## 再看 physical_keycode，两个都填就不用赌它走哪条分支。
func _press(key: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	return event


func _release(key: Key) -> InputEventKey:
	var event: InputEventKey = _press(key)
	event.pressed = false
	return event


# ── 格位布局 ──────────────────────────────────────────────

## 快捷栏格数必须等于工具数 + 种子数，且不超过按键数。
func test_hotbar_layout_matches_the_databases() -> void:
	var tools: Array[String] = ToolDatabase.all_ids()
	var crops: Array[String] = CropDatabase.all_ids()

	assert_gt(tools.size(), 0, "先确认工具数据库不是空的")
	assert_gt(crops.size(), 0, "先确认作物数据库不是空的")
	assert_eq(
		GameManager.hotbar.size(), Hotbar.SLOT_COUNT,
		"快捷栏格数应该正好是 Hotbar.SLOT_COUNT",
	)
	assert_lte(
		tools.size() + crops.size(), Hotbar.SLOT_COUNT,
		"工具 + 种子数不能超过格子数，多出来的会被静默丢掉",
	)


## 格位顺序：前几格是工具（声明顺序），接着是种子（声明顺序）。
func test_slot_order_is_tools_then_seeds() -> void:
	var tools: Array[String] = ToolDatabase.all_ids()
	var crops: Array[String] = CropDatabase.all_ids()

	for i: int in tools.size():
		var entry: HotbarEntry = GameManager.hotbar.entry_at(i)
		assert_not_null(entry, "第 %d 格应该存在" % (i + 1))
		assert_true(entry.is_tool(), "第 %d 格应该是工具 %s" % [i + 1, tools[i]])
		assert_eq(entry.id, tools[i], "第 %d 格应该是 %s" % [i + 1, tools[i]])

	var seed_start: int = GameManager.hotbar.first_seed_index()
	assert_eq(seed_start, tools.size(), "种子应该紧跟在工具之后")
	for i: int in crops.size():
		var entry: HotbarEntry = GameManager.hotbar.entry_at(seed_start + i)
		assert_not_null(entry, "第 %d 格应该存在" % (seed_start + i + 1))
		assert_eq(
			entry.id, crops[i],
			"第 %d 格应该是 %s（快捷栏顺序 = 数据表声明顺序）" % [seed_start + i + 1, crops[i]],
		)


# ── 映射表本身 ────────────────────────────────────────────

## 每一格都必须有一个真实存在的输入动作。
## 以后加第 13 格、或把 SLOT_COUNT 调大却忘了加 tool_13，这里会立刻红。
func test_every_slot_has_a_bound_action() -> void:
	assert_eq(
		GameManager.TOOL_ACTIONS.size(), Hotbar.SLOT_COUNT,
		"TOOL_ACTIONS 的条数必须正好等于格数，多一个或少一个都会让末几格失灵",
	)
	assert_lte(
		Hotbar.SLOT_COUNT, EXPECTED_SLOT_KEYS.size(),
		"键盘上能用的格位键只有 %d 个，格子比它多就没法全绑上" % EXPECTED_SLOT_KEYS.size(),
	)

	for i: int in GameManager.TOOL_ACTIONS.size():
		var action: StringName = GameManager.TOOL_ACTIONS[i]
		assert_true(
			InputMap.has_action(action),
			"第 %d 格缺少输入动作 %s，请去 project.godot 的 [input] 段补上" % [i + 1, action],
		)


## 每个快捷栏动作都必须真的绑了键，否则是个空壳。
func test_slot_actions_are_not_empty() -> void:
	for action: StringName in GameManager.TOOL_ACTIONS:
		if not InputMap.has_action(action):
			continue
		assert_gt(
			InputMap.action_get_events(action).size(), 0,
			"输入动作 %s 存在但没有绑定任何键" % action,
		)


func test_advance_day_action_is_bound() -> void:
	assert_true(
		InputMap.has_action(GameManager.ACTION_ADVANCE_DAY),
		"过夜动作 %s 必须在 project.godot 里定义" % GameManager.ACTION_ADVANCE_DAY,
	)


func test_use_item_action_is_bound_to_left_mouse() -> void:
	assert_true(InputMap.has_action("use_item"), "使用手持物的动作必须存在")
	var has_left: bool = false
	for event: InputEvent in InputMap.action_get_events("use_item"):
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				has_left = true
	assert_true(has_left, "使用手持物必须绑在鼠标左键上")


## ★ 回归测试 ★ 教学作物芜菁还必须在"第一格种子"。
##
## 曾经的坑：`all_ids()` 按 id 字母排序，"parsnip" 排到第 6 ——
## 开局默认选中的芜菁高亮在 6 号格，按 1 选中的却是夏作物的蓝莓，
## 玩家在春天按 1 怎么种都种不下去，看起来就像"游戏坏了"。
## 现在第 1 格让给了锄头，所以芜菁顺位到"第一格种子"，必须紧跟在工具之后。
func test_parsnip_is_the_first_seed_right_after_the_tools() -> void:
	var crops: Array[String] = CropDatabase.all_ids()
	var seed_start: int = GameManager.hotbar.first_seed_index()

	assert_eq(crops[0], "parsnip", "芜菁（教学作物）必须是第一格种子，顺序 = 声明顺序（春→夏→秋）")
	assert_eq(
		seed_start, ToolDatabase.all_ids().size(),
		"第一格种子应该紧跟在工具之后，中间不能有空位",
	)
	assert_eq(
		GameManager.hotbar.index_of_crop("parsnip"), seed_start,
		"按 id 反查也要落到同一格",
	)


## 开局手持锄头 —— 第一天第一件事就是开垦，教具要放在最好按的那一格。
func test_default_slot_is_the_hoe() -> void:
	var entry: HotbarEntry = GameManager.hotbar.entry_at(0)
	assert_not_null(entry, "第 1 格必须存在")
	assert_eq(entry.id, ToolDatabase.HOE, "第 1 格应该是锄头")
	assert_eq(
		GameManager.hotbar.first_tool_index(), 0,
		"工具区必须从第 1 格开始，否则最好按的键会浪费在空位上",
	)


# ── 代码读映射表的结果 ────────────────────────────────────

## ★ 核心用例 ★
## 逐个按下 12 个键，必须依次命中第 0~11 格。
## 这条同时验证了两件事：动作确实绑在这些键上；`slot_for_event` 的遍历顺序没错位。
func test_pressing_number_keys_maps_to_matching_slots() -> void:
	for i: int in EXPECTED_SLOT_KEYS.size():
		var slot: int = GameManager.slot_for_event(_press(EXPECTED_SLOT_KEYS[i]))
		assert_eq(
			slot, i,
			"按下 %s 应该命中第 %d 格，实际命中 %d" % [EXPECTED_SLOT_KEYS[i], i + 1, slot + 1],
		)


## 按下第 N 格后，`selected_slot` 必须正好是 N−1，并广播 slot_selected。
func test_slot_selection_updates_state_and_broadcasts() -> void:
	for i: int in EXPECTED_SLOT_KEYS.size():
		var slot: int = GameManager.slot_for_event(_press(EXPECTED_SLOT_KEYS[i]))
		assert_gte(slot, 0, "第 %d 格应该有对应的按键" % (i + 1))
		if slot < 0:
			continue

		watch_signals(EventBus)

		GameManager.use_slot(slot)

		assert_eq(
			GameManager.selected_slot, slot,
			"选中第 %d 格后 selected_slot 应该等于 %d" % [i + 1, slot],
		)
		# 注意：这个断言的第 4 个参数是「第几次发射」，不是提示文案，别多传。
		assert_signal_emitted_with_parameters(EventBus, "slot_selected", [slot])


## 手持物必须跟着格位变 —— 这正是"选锄头才能耕地"的落点。
func test_selected_entry_follows_the_slot() -> void:
	var tools: Array[String] = ToolDatabase.all_ids()
	var seed_start: int = GameManager.hotbar.first_seed_index()

	GameManager.use_slot(0)
	assert_eq(GameManager.selected_tool().id, tools[0], "第 1 格应该手持第一件工具")
	assert_null(GameManager.selected_crop(), "拿着工具时不该有选中的种子")

	GameManager.use_slot(seed_start)
	assert_not_null(GameManager.selected_crop(), "第一格种子应该能取出 CropData")
	assert_null(GameManager.selected_tool(), "拿着种子时不该有选中的工具")


## 没绑定任何动作的键必须是 −1，否则别的键会被误当成换格位。
func test_unbound_keys_do_not_select_any_slot() -> void:
	for key: Key in [KEY_Z, KEY_ENTER, KEY_F11, KEY_SPACE, KEY_SHIFT]:
		assert_eq(
			GameManager.slot_for_event(_press(key)), -1,
			"%s 没有绑定快捷栏动作，不该命中任何格位" % key,
		)


## 松键不能触发换格位，否则一次按键会切两次（按下一次、松开又一次）。
func test_key_release_does_not_select() -> void:
	assert_eq(
		GameManager.slot_for_event(_release(KEY_3)), -1,
		"松开数字键不该切换格位",
	)


## 越界格位必须被安全忽略，不能抛错、不能选中不存在的格。
func test_out_of_range_slots_are_ignored() -> void:
	var before: int = GameManager.selected_slot
	var count: int = GameManager.hotbar.size()

	for slot: int in [count, 99, -1]:
		GameManager.use_slot(slot)

	assert_eq(
		GameManager.selected_slot, before,
		"越界格位应该被忽略，当前手持保持不变",
	)
