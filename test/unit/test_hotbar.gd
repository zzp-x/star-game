extends GutTest
## 单元测试：快捷栏布局（L2 纯逻辑，不启动场景树）。
##
## 【为什么这类东西值得单测】"第 N 格是什么"这个映射被三处依赖：
##   ① 玩家按的键（project.godot 的 tool_N）
##   ② HUD 画出来的格子和角标数字
##   ③ GameManager 里"手持物决定能做什么"的分派
## 三处一旦错位一格，症状是"我按 2 想浇水，人却在锄地" ——
## 看起来像玄学，排查起来却要把三个文件来回对。
## 把布局本身抽成纯逻辑，就能在这里一次性测干净。


func test_layout_is_exactly_slot_count_long() -> void:
	var bar: Hotbar = Hotbar.new()
	assert_eq(bar.size(), Hotbar.SLOT_COUNT, "格数必须正好是 SLOT_COUNT")


## 工具区在前、种子区在后，中间不能有空洞 ——
## 有空位就意味着"最好按的几个键被浪费了"。
func test_tools_come_first_without_gaps() -> void:
	var bar: Hotbar = Hotbar.new()
	var tools: Array[String] = ToolDatabase.all_ids()

	assert_gt(tools.size(), 0, "先确认工具表不是空的")

	for i: int in tools.size():
		var entry: HotbarEntry = bar.entry_at(i)
		assert_not_null(entry, "第 %d 格应该存在" % (i + 1))
		assert_true(entry.is_tool(), "第 %d 格应该是工具" % (i + 1))
		assert_eq(entry.id, tools[i], "工具顺序应该等于声明顺序")

	assert_eq(bar.entry_at(tools.size()).is_seed(), true, "工具之后要紧接着种子，不能有空位")


func test_seed_slots_follow_crop_declaration_order() -> void:
	var bar: Hotbar = Hotbar.new()
	var crops: Array[String] = CropDatabase.all_ids()
	var start: int = bar.first_seed_index()

	assert_eq(start, ToolDatabase.all_ids().size(), "种子区起始下标 = 工具数")

	for i: int in crops.size():
		var entry: HotbarEntry = bar.entry_at(start + i)
		assert_not_null(entry, "第 %d 格应该存在" % (start + i + 1))
		assert_eq(entry.id, crops[i], "第 %d 格应该是 %s" % [start + i + 1, crops[i]])


func test_index_lookup_agrees_with_position() -> void:
	var bar: Hotbar = Hotbar.new()

	for i: int in bar.size():
		var entry: HotbarEntry = bar.entry_at(i)
		assert_not_null(entry, "第 %d 格应该存在" % (i + 1))
		if entry.is_tool():
			assert_eq(bar.index_of_tool(entry.id), i, "%s 的反查应该回到第 %d 格" % [entry.id, i + 1])
		elif entry.is_seed():
			assert_eq(bar.index_of_crop(entry.id), i, "%s 的反查应该回到第 %d 格" % [entry.id, i + 1])


func test_unknown_ids_return_minus_one() -> void:
	var bar: Hotbar = Hotbar.new()
	assert_eq(bar.index_of_tool("no_such_tool"), -1, "不存在的工具应该返回 −1")
	assert_eq(bar.index_of_crop("no_such_crop"), -1, "不存在的作物应该返回 −1")
	# 拿工具 id 去查种子、拿种子 id 去查工具，都必须落空 ——
	# 否则"选种子"会意外切到一把工具
	assert_eq(bar.index_of_crop(ToolDatabase.HOE), -1, "工具 id 不该在种子区命中")
	assert_eq(bar.index_of_tool("parsnip"), -1, "作物 id 不该在工具区命中")


func test_out_of_range_access_returns_null() -> void:
	var bar: Hotbar = Hotbar.new()
	assert_null(bar.entry_at(-1), "负下标应该返回 null")
	assert_null(bar.entry_at(bar.size()), "越界下标应该返回 null")


# ── 一格自身 ──────────────────────────────────────────────

func test_empty_entry_has_no_identity() -> void:
	var empty: HotbarEntry = HotbarEntry.make_empty()
	assert_true(empty.is_empty(), "空位应该 is_empty")
	assert_false(empty.is_tool(), "空位不是工具")
	assert_false(empty.is_seed(), "空位不是种子")
	assert_eq(empty.id, "", "空位没有 id")


## 种子的季节白名单要抄进格子里：HUD 每帧都在画 12 格，
## 不能为了判一次季节去查一遍数据表。
func test_seed_entry_carries_its_seasons() -> void:
	var spring_only: HotbarEntry = HotbarEntry.make_seed(CropDatabase.get_crop("parsnip"))
	assert_true(spring_only.grows_in_season(Clock.SPRING), "芜菁春天能种")
	assert_false(spring_only.grows_in_season(Clock.WINTER), "芜菁冬天不能种")


## 工具与季节无关 —— 冬天照样能拿锄头翻地。
func test_tool_entry_ignores_seasons() -> void:
	var hoe: HotbarEntry = HotbarEntry.make_tool(ToolDatabase.get_tool(ToolDatabase.HOE))
	for season: int in [Clock.SPRING, Clock.SUMMER, Clock.FALL, Clock.WINTER]:
		assert_true(hoe.grows_in_season(season), "工具没有季节限制")
