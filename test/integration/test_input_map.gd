extends GutTest
## 集成测试：验证 `project.godot` 的输入映射表与代码真的对得上。
##
## 【为什么需要这类测试】
## 输入映射是一份「配置」，代码是另一份「事实」。两者一旦脱节，症状是
## 「照着映射表改了键 / 加了新作物，游戏里毫无反应」—— 极难排查，
## 因为代码能跑、测试全绿、日志无错，只是你按的那个键没人听。
##
## 这个项目就真的出现过：映射表里只有 `tool_1`~`tool_5`，
## 而代码直接用 `physical_keycode - KEY_1` 自己算 ——
## 于是映射表成了一摆设，后来把快捷栏扩到 9 格时，`tool_6`~`tool_9` 根本不存在。
## 本文件锁死「动作存在」+「动作能对上格位」两件事。

const EXPECTED_SLOT_KEYS: Array[Key] = [
	KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9,
]


func before_each() -> void:
	GameManager.selected_crop_id = "parsnip"


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


# ── 映射表本身 ────────────────────────────────────────────

## 每种作物都必须有一个真实存在的快捷栏动作。
## 加第 10 种作物时如果忘了加 tool_10，这里会立刻红。
func test_every_crop_has_a_bound_slot_action() -> void:
	var ids: Array[String] = CropDatabase.all_ids()

	assert_gt(ids.size(), 0, "先确认作物数据库不是空的，否则这条测试没有意义")
	assert_gte(
		GameManager.TOOL_ACTIONS.size(), ids.size(),
		"快捷栏动作数不能少于作物种类数，否则末尾的种子没有快捷键",
	)

	for i: int in range(ids.size()):
		var action: StringName = GameManager.TOOL_ACTIONS[i]
		assert_true(
			InputMap.has_action(action),
			"作物「%s」（第 %d 格）缺少输入动作 %s，请去 project.godot 的 [input] 段补上"
			% [ids[i], i + 1, action],
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


# ── 代码读映射表的结果 ────────────────────────────────────

## ★ 核心用例 ★
## 逐个按下 1~9，必须依次命中第 0~8 格。
## 这条同时验证了两件事：动作确实绑在数字键上；`slot_for_event` 的遍历顺序没错位。
func test_pressing_number_keys_maps_to_matching_slots() -> void:
	# 只测库里有作物的那几格，多出来的动作（如果以后有）不参与
	var count: int = mini(EXPECTED_SLOT_KEYS.size(), CropDatabase.all_ids().size())

	for i: int in range(count):
		var slot: int = GameManager.slot_for_event(_press(EXPECTED_SLOT_KEYS[i]))
		assert_eq(
			slot, i,
			"按下 %s 应该命中第 %d 格，实际命中 %d" % [EXPECTED_SLOT_KEYS[i], i + 1, slot + 1],
		)


## 按下第 N 格后，选中的种子必须正好是第 N 种作物。
func test_slot_selection_actually_switches_the_crop() -> void:
	var ids: Array[String] = CropDatabase.all_ids()
	var count: int = mini(EXPECTED_SLOT_KEYS.size(), ids.size())

	for i: int in range(count):
		var slot: int = GameManager.slot_for_event(_press(EXPECTED_SLOT_KEYS[i]))
		assert_gte(slot, 0, "第 %d 格应该有对应的按键" % (i + 1))
		if slot < 0:
			continue

		# 用 GUT 的信号监视，而不是自己接 lambda 收参数 ——
		# 少一个"我接的信号到底有没有生效"的疑问。
		watch_signals(EventBus)

		GameManager.use_slot(slot)

		assert_eq(
			GameManager.selected_crop_id, ids[slot],
			"选中第 %d 格后应该切换到 %s" % [slot + 1, ids[slot]],
		)
		# 注意：这个断言的第 4 个参数是「第几次发射」，不是提示文案，别多传。
		assert_signal_emitted_with_parameters(
			EventBus, "crop_selected", [ids[slot]],
		)


## 没绑定任何动作的键必须是 −1，否则箭头键 / 功能键会被误当成换种子。
func test_unbound_keys_do_not_select_any_slot() -> void:
	for key: Key in [KEY_0, KEY_Z, KEY_ENTER, KEY_F11]:
		assert_eq(
			GameManager.slot_for_event(_press(key)), -1,
			"%s 没有绑定快捷栏动作，不该命中任何格位" % key,
		)


## 松键不能触发换种子，否则一次按键会切两次（按下一次、松开又一次）。
func test_key_release_does_not_select() -> void:
	assert_eq(
		GameManager.slot_for_event(_release(KEY_3)), -1,
		"松开数字键不该切换种子",
	)


## 越界格位必须被安全忽略，不能抛错、不能选中不存在的作物。
func test_out_of_range_slots_are_ignored() -> void:
	var before: String = GameManager.selected_crop_id
	var ids_count: int = CropDatabase.all_ids().size()

	for slot: int in [ids_count, 99, -1]:
		GameManager.use_slot(slot)

	assert_eq(
		GameManager.selected_crop_id, before,
		"越界格位应该被忽略，当前种子保持不变",
	)
