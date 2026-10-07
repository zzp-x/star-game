extends GutTest
## 集成测试：**手持什么，就只能做什么**。
##
## 【为什么这是"规则"而不是"手感"】
## M0 的左键是「智能操作」：点一下自动决定翻地 / 播种 / 浇水 / 收割。
## 上手最快，但快捷栏形同虚设 —— 手上拿什么跟能做什么毫无关系。
## M0.5 改成工具门槛后，"选锄头才能耕地"变成一条**会被玩家反复验证**的规则：
## 拿错了点不动，玩家立刻会怀疑"是不是卡了"。
##
## 所以每条门槛都要有明确的提示文案 + "不该发生的事情确实没发生"
## （地里没多出 tile、体力没被扣、状态没被改）。
## 只说"返回了提示"是不够的 —— 提示对、副作用错才是最恶心的 bug。

const CELL: Vector2i = Vector2i(5, 5)
const OTHER: Vector2i = Vector2i(6, 5)


func before_each() -> void:
	GameManager.farm = FarmGrid.new()
	GameManager.stamina = GameManager.MAX_STAMINA
	GameManager.money = GameManager.INITIAL_MONEY
	GameManager.use_slot(0)
	TimeManager.weather = Weather.SUNNY


func _hold_tool(tool_id: String) -> void:
	assert_true(GameManager.select_tool(tool_id), "应该能切到工具 %s" % tool_id)


func _hold_crop(crop_id: String) -> void:
	assert_true(GameManager.select_crop(crop_id), "应该能切到种子 %s" % crop_id)


# ── 锄头：只能翻地 ───────────────────────────────────────

func test_hoe_tills_grass() -> void:
	_hold_tool(ToolDatabase.HOE)
	assert_eq(GameManager.use_item(CELL), "翻地")
	assert_eq(GameManager.farm.peek(CELL).state, FarmTile.State.TILLED)


func test_hoe_cannot_till_twice() -> void:
	_hold_tool(ToolDatabase.HOE)
	GameManager.use_item(CELL)
	var stamina_before: int = GameManager.stamina

	assert_eq(GameManager.use_item(CELL), "这块地已经翻好了")
	assert_eq(GameManager.stamina, stamina_before, "无效操作不该扣体力")


func test_hoe_cannot_dig_up_a_planted_tile() -> void:
	GameManager.farm.till(CELL)
	GameManager.farm.plant(CELL, "parsnip")
	_hold_tool(ToolDatabase.HOE)
	var stamina_before: int = GameManager.stamina

	var message: String = GameManager.use_item(CELL)

	assert_true(message.contains("芜菁"), "应该告诉玩家这块地种的是什么（实际：%s）" % message)
	assert_eq(GameManager.farm.peek(CELL).crop_id, "parsnip", "锄头不能把作物挖掉")
	assert_eq(GameManager.stamina, stamina_before, "无效操作不该扣体力")


## ★ 核心用例 ★ 拿锄头收割不了 —— 必须换镰刀。
func test_hoe_cannot_harvest_a_mature_crop() -> void:
	var data: CropData = CropDatabase.get_crop("parsnip")
	GameManager.farm.till(CELL)
	GameManager.farm.plant(CELL, "parsnip")
	GameManager.farm.peek(CELL).growth = data.mature_days

	_hold_tool(ToolDatabase.HOE)
	GameManager.use_item(CELL)

	assert_eq(GameManager.farm.peek(CELL).crop_id, "parsnip", "成熟作物必须还在，锄头收不了")


# ── 洒水壶：只能浇水 ─────────────────────────────────────

func test_can_only_water_tilled_soil() -> void:
	_hold_tool(ToolDatabase.CAN)
	var stamina_before: int = GameManager.stamina

	assert_eq(GameManager.use_item(CELL), "要先用锄头翻地")
	assert_false(GameManager.farm.has_tile(CELL), "水壶不该把荒地开垦出来")
	assert_eq(GameManager.stamina, stamina_before, "无效操作不该扣体力")


func test_can_cannot_till() -> void:
	_hold_tool(ToolDatabase.CAN)
	GameManager.use_item(CELL)

	assert_false(GameManager.farm.has_tile(CELL), "整个流程里就没有任何东西翻过这块地")


func test_can_waters() -> void:
	GameManager.farm.till(CELL)
	_hold_tool(ToolDatabase.CAN)

	assert_eq(GameManager.use_item(CELL), "浇水")
	assert_eq(GameManager.farm.peek(CELL).state, FarmTile.State.WATERED)


func test_can_does_not_water_twice() -> void:
	GameManager.farm.till(CELL)
	_hold_tool(ToolDatabase.CAN)
	GameManager.use_item(CELL)
	var stamina_before: int = GameManager.stamina

	assert_eq(GameManager.use_item(CELL), "已经浇过水了")
	assert_eq(GameManager.stamina, stamina_before, "重复浇水不该扣体力")


# ── 镰刀：只能收割 ───────────────────────────────────────

func test_sickle_only_harvests_mature_crops() -> void:
	_hold_tool(ToolDatabase.SICKLE)
	var stamina_before: int = GameManager.stamina

	assert_eq(GameManager.use_item(CELL), "这里没有可以收割的作物")
	assert_false(GameManager.farm.has_tile(CELL), "镰刀不该把荒地开垦出来")
	assert_eq(GameManager.stamina, stamina_before, "无效操作不该扣体力")


func test_sickle_refuses_unripe_crops() -> void:
	GameManager.farm.till(CELL)
	GameManager.farm.plant(CELL, "parsnip")
	_hold_tool(ToolDatabase.SICKLE)
	var stamina_before: int = GameManager.stamina

	var message: String = GameManager.use_item(CELL)

	assert_true(message.contains("还要"), "应该告诉玩家还差几天（实际：%s）" % message)
	assert_eq(GameManager.farm.peek(CELL).crop_id, "parsnip", "没熟就收不下来")
	assert_eq(GameManager.stamina, stamina_before, "无效操作不该扣体力")


func test_sickle_harvests_mature_crops_and_pays_out() -> void:
	var data: CropData = CropDatabase.get_crop("parsnip")
	GameManager.farm.till(CELL)
	GameManager.farm.plant(CELL, "parsnip")
	GameManager.farm.peek(CELL).growth = data.mature_days

	_hold_tool(ToolDatabase.SICKLE)
	var money_before: int = GameManager.money
	var message: String = GameManager.use_item(CELL)

	assert_true(message.begins_with("收获"), "应该收获成功（实际：%s）" % message)
	assert_eq(GameManager.farm.peek(CELL).crop_id, "", "收获后作物清空")
	assert_gt(GameManager.money, money_before, "收获要进账")


# ── 种子：只能播种 ───────────────────────────────────────

func test_seed_requires_tilled_soil() -> void:
	_hold_crop("parsnip")
	var stamina_before: int = GameManager.stamina

	assert_eq(GameManager.use_item(CELL), "要先用锄头翻地")
	assert_false(GameManager.farm.has_tile(CELL), "种子不该把荒地开垦出来")
	assert_eq(GameManager.stamina, stamina_before, "无效操作不该扣体力")


func test_seed_cannot_overwrite_an_existing_crop() -> void:
	GameManager.farm.till(CELL)
	GameManager.farm.plant(CELL, "parsnip")
	_hold_crop("potato")
	var stamina_before: int = GameManager.stamina

	var message: String = GameManager.use_item(CELL)

	assert_true(message.contains("芜菁"), "应该告诉玩家这块地已经种了什么（实际：%s）" % message)
	assert_eq(GameManager.farm.peek(CELL).crop_id, "parsnip", "不能把已有作物顶掉")
	assert_eq(GameManager.stamina, stamina_before, "无效操作不该扣体力")


## ★ 回归测试 ★ 季节白名单要在扣体力**之前**判。
##
## 曾经的 bug：先 `_spend` 再 `plant`，而 plant 会因季节白名单失败 ——
## 结果「种不下去，但体力已经扣了，提示还写着体力不足」，
## 玩家完全不知道该去怪季节还是怪体力。
func test_out_of_season_seed_does_not_cost_stamina() -> void:
	GameManager.farm.till(CELL)
	var season_backup: int = TimeManager.clock.season
	TimeManager.clock.season = Clock.WINTER
	_hold_crop("melon")
	var stamina_before: int = GameManager.stamina

	var message: String = GameManager.use_item(CELL)

	TimeManager.clock.season = season_backup

	assert_false(message == "体力不足", "不该把季节问题误报成体力问题（实际：%s）" % message)
	assert_true(message.contains("不能"), "应该明确说「不能在某个季节播种」（实际：%s）" % message)
	assert_eq(GameManager.stamina, stamina_before, "季节不对不该扣体力")
	assert_eq(GameManager.farm.peek(CELL).crop_id, "", "冬天种不下甜瓜")


# ── 空位 ─────────────────────────────────────────────────

func test_empty_slot_does_nothing() -> void:
	var last: int = GameManager.hotbar.size() - 1
	var entry: HotbarEntry = GameManager.hotbar.entry_at(last)
	assert_not_null(entry, "最后一格必须存在")

	# 只有当最后一格真的是空位时才测 —— 库里作物补齐 12 格之后这条会自然失效
	if not entry.is_empty():
		return

	GameManager.use_slot(last)
	assert_eq(GameManager.use_item(CELL), "这一格是空的")
	assert_false(GameManager.farm.has_tile(CELL), "空手不该产生任何副作用")
