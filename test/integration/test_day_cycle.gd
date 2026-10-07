extends GutTest
## 集成测试：验证「L3 单例 + EventBus + L2 规则」这条链路真的接对了。
##
## 【为什么必须有这类测试】
## 单元测试证明 `FarmGrid` 的规则是对的，但证明不了
## 「`TimeManager.sleep()` 真的会驱动作物生长」—— 这中间隔着：
##   · Autoload 的加载顺序
##   · EventBus 信号的连接时机
##   · weather_rolled 与 day_changed 的发射先后
##   · _unhandled_input 是否真的能收到事件
## 这类接线 bug 单元测试永远抓不到，而在 3D 里手动验证一次要花好几分钟
## （要走到田里、要点鼠标、要等太阳升起）。所以这里的价值特别高。

const CELL: Vector2i = Vector2i(3, 3)


func before_each() -> void:
	# 每个测试都从干净的农场开始 —— autoload 是全局的，必须手动重置
	GameManager.farm = FarmGrid.new()
	GameManager.stamina = GameManager.MAX_STAMINA
	GameManager.money = GameManager.INITIAL_MONEY
	# 开局手持锄头（与游戏启动时一致）
	GameManager.use_slot(0)
	TimeManager.weather = Weather.SUNNY


func _plant_watered() -> void:
	GameManager.farm.till(CELL)
	GameManager.farm.plant(CELL, "parsnip")
	GameManager.farm.water(CELL)


# ── 跨天链路 ─────────────────────────────────────────────

func test_sleep_advances_watered_crop() -> void:
	_plant_watered()

	TimeManager.sleep()

	assert_eq(GameManager.farm.peek(CELL).growth, 1, "睡一觉后浇过水的作物应该长 1 天")


func test_sleep_does_not_advance_unwatered_crop() -> void:
	GameManager.farm.till(CELL)
	GameManager.farm.plant(CELL, "parsnip")

	TimeManager.sleep()

	assert_eq(GameManager.farm.peek(CELL).growth, 0, "没浇水，睡再多也不长")


func test_sleep_in_rain_waters_everything() -> void:
	GameManager.farm.till(CELL)
	GameManager.farm.plant(CELL, "parsnip")
	TimeManager.weather = Weather.RAIN

	TimeManager.sleep()

	assert_eq(GameManager.farm.peek(CELL).growth, 1, "雨天自动浇水")


func test_sleep_restores_stamina() -> void:
	GameManager.stamina = 10

	TimeManager.sleep()

	assert_eq(GameManager.stamina, GameManager.MAX_STAMINA, "睡醒体力回满")


func test_sleep_advances_calendar() -> void:
	var day_before: int = TimeManager.clock.day

	TimeManager.sleep()

	assert_eq(TimeManager.clock.day, day_before + 1, "跨一天")


## ★ 回归测试 ★
## 曾经的 bug：作物生长挂在 `day_changed` 上、并读取 `TimeManager.weather`；
## 而 `sleep()` 在发射 `day_changed` **之前**已经掷好了新一天的天气 ——
## 于是"明天要下雨"变成了"今晚不长也得长"。
##
## 这个 bug 单元测试抓不到（FarmGrid 的逻辑完全正确），
## 3D 里手动验证也很难发现（要恰好碰上"明天雨、今天没浇水"）。
## 现在生长改挂 `day_ended`（携带刚结束那天的天气），本测试锁死这个行为。
func test_tomorrow_rain_does_not_grow_crops_tonight() -> void:
	# 固定在「春 10 日」，保证跨天不会跨季（否则天气权重表会变，种子搜索失效）
	TimeManager.clock = Clock.new(1, Clock.SPRING, 10)

	GameManager.farm.till(CELL)
	GameManager.farm.plant(CELL, "parsnip")
	# 注意：故意不浇水
	TimeManager.weather = Weather.SUNNY

	# 强制让"新一天"必然掷出雨天
	var seed_for_rain: int = _find_seed_producing(Clock.SPRING, Weather.RAIN)
	assert_gt(seed_for_rain, 0, "应该能找到一个必然掷出雨天的种子")
	TimeManager.rng.seed = seed_for_rain

	TimeManager.sleep()

	assert_eq(TimeManager.weather, Weather.RAIN, "新一天的天气应该是雨")
	assert_eq(
		GameManager.farm.peek(CELL).growth, 0,
		"生长只取决于刚结束那天的天气 —— 明天的雨不该让今晚的作物生长",
	)


## 穷举种子，找一个「在指定季节必然掷出目标天气」的种子，让随机行为可复现。
func _find_seed_producing(season: int, target_weather: int) -> int:
	var probe: RandomNumberGenerator = RandomNumberGenerator.new()
	for s: int in range(1, 5000):
		probe.seed = s
		if Weather.roll(season, probe) == target_weather:
			return s
	return -1


# ── 完整闭环（一路换手持物）───────────────────────────────

## 从荒草地一路种到收成：锄头翻地 → 播种 → 水壶浇水 → 过夜 → 镰刀收割。
##
## 【为什么改成"换工具"而不是"一直点左键"】M0.5 起左键只做手持物那一件事。
##   这条测试因此顺带验证了"换手持物真的换了行为" ——
##   拿锄头能翻地、拿水壶就翻不了，规则只有一处。
func test_full_loop_by_switching_tools() -> void:
	var cell: Vector2i = CELL

	# ① 锄头翻地
	assert_true(GameManager.select_tool(ToolDatabase.HOE), "锄头必须能切到")
	assert_eq(GameManager.use_item(cell), "翻地")
	assert_eq(
		GameManager.farm.peek(cell).state, FarmTile.State.TILLED,
		"手持锄头点草地 → 翻地",
	)

	# ② 种子播种
	assert_true(GameManager.select_crop("parsnip"), "芜菁种子必须能切到")
	assert_eq(GameManager.use_item(cell), "播种 芜菁")
	assert_eq(GameManager.farm.peek(cell).crop_id, "parsnip", "手持种子点已翻土 → 播种")

	# ③ 水壶浇水
	assert_true(GameManager.select_tool(ToolDatabase.CAN), "洒水壶必须能切到")
	assert_eq(GameManager.use_item(cell), "浇水")
	assert_eq(
		GameManager.farm.peek(cell).state, FarmTile.State.WATERED,
		"手持水壶点已播种的土 → 浇水",
	)

	var data: CropData = CropDatabase.get_crop("parsnip")
	assert_not_null(data)

	# 每天浇水 + 过夜，直到成熟（带安全上限，避免死循环卡住 CI）
	for i: int in range(data.mature_days + 3):
		if GameManager.farm.peek(cell).is_mature(data.mature_days):
			break
		GameManager.stamina = GameManager.MAX_STAMINA
		GameManager.select_tool(ToolDatabase.CAN)
		GameManager.use_item(cell)
		TimeManager.sleep()

	assert_true(
		GameManager.farm.peek(cell).is_mature(data.mature_days),
		"循环浇水 + 过夜应该能种熟一株芜菁",
	)

	var money_before: int = GameManager.money
	GameManager.stamina = GameManager.MAX_STAMINA

	# ④ 镰刀收割
	assert_true(GameManager.select_tool(ToolDatabase.SICKLE), "镰刀必须能切到")
	var message: String = GameManager.use_item(cell)

	assert_true(
		message.begins_with("收获"), "手持镰刀点成熟作物 → 收割（实际提示：%s）" % message,
	)
	assert_gt(GameManager.money, money_before, "收获应该进账")
	assert_eq(GameManager.farm.peek(cell).crop_id, "", "收获后地变空")
	assert_eq(GameManager.farm.peek(cell).state, FarmTile.State.TILLED, "地仍可继续种")


func test_using_a_tool_spends_stamina() -> void:
	GameManager.stamina = GameManager.MAX_STAMINA
	GameManager.select_tool(ToolDatabase.HOE)

	GameManager.use_item(CELL)

	assert_lt(GameManager.stamina, GameManager.MAX_STAMINA, "翻地要消耗体力")


func test_no_stamina_blocks_action() -> void:
	GameManager.stamina = 0
	GameManager.select_tool(ToolDatabase.HOE)

	var message: String = GameManager.use_item(CELL)

	assert_eq(message, "体力不足", "没体力时应该明确提示")
	assert_false(GameManager.farm.has_tile(CELL), "没体力就不该发生任何农场操作")


func test_season_whitelist_blocks_out_of_season_planting() -> void:
	GameManager.farm.till(CELL)
	var season_backup: int = TimeManager.clock.season
	TimeManager.clock.season = Clock.WINTER

	assert_false(GameManager.plant(CELL, "melon"), "冬天不能种夏季的甜瓜")

	TimeManager.clock.season = season_backup


# ── 存档链路 ─────────────────────────────────────────────

func test_save_then_load_restores_farm() -> void:
	_plant_watered()
	var before: int = GameManager.farm.peek(CELL).growth

	assert_true(SaveManager.save_game(3), "存档应该成功")

	GameManager.farm = FarmGrid.new()
	assert_null(GameManager.farm.peek(CELL), "先清空农场")

	assert_true(SaveManager.load_game(3), "读档应该成功")

	var tile: FarmTile = GameManager.farm.peek(CELL)
	assert_not_null(tile, "读档后格子应该恢复")
	assert_eq(tile.crop_id, "parsnip")
	assert_eq(tile.growth, before)
	assert_eq(tile.state, FarmTile.State.WATERED)

	SaveManager.delete_save(3)


## 手持格位要跟着存档走 —— 否则读档回来"手上拿的东西变了"，
## 玩家会以为自己记错了。
func test_save_keeps_the_held_slot() -> void:
	GameManager.select_tool(ToolDatabase.SICKLE)
	var slot_before: int = GameManager.selected_slot

	assert_true(SaveManager.save_game(3), "存档应该成功")

	GameManager.use_slot(0)
	assert_ne(GameManager.selected_slot, slot_before, "先切走，确保读档真的把它改回来")

	assert_true(SaveManager.load_game(3), "读档应该成功")
	assert_eq(GameManager.selected_slot, slot_before, "读档后手持格位应该恢复")

	SaveManager.delete_save(3)


## ★ 旧档兼容 ★ M0 的存档里存的是 `selected_crop_id`（当时快捷栏只有种子）。
## 读进来必须翻译成新布局里对应的种子格，而不是静默跳回锄头。
func test_legacy_save_with_crop_id_migrates_to_the_seed_slot() -> void:
	var data: Dictionary = GameManager.to_dict()
	data.erase("selected_slot")
	data["selected_crop_id"] = "pumpkin"

	GameManager.from_dict(data)

	assert_eq(
		GameManager.selected_slot, GameManager.hotbar.index_of_crop("pumpkin"),
		"老档里的 selected_crop_id 应该被翻译成新布局的种子格",
	)
	assert_eq(GameManager.selected_crop().id, "pumpkin", "读档后手上还是原来那种种子")


## 老档里的作物 id 已经不存在时，不能崩，也不能选中奇怪的东西。
func test_legacy_save_with_unknown_crop_id_falls_back_safely() -> void:
	var data: Dictionary = GameManager.to_dict()
	data.erase("selected_slot")
	data["selected_crop_id"] = "no_such_crop"

	GameManager.from_dict(data)

	assert_eq(
		GameManager.selected_slot, 0,
		"认不出来的旧作物 id 应该退回第 1 格（锄头），而不是越界",
	)
