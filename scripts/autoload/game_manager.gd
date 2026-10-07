extends Node
## 游戏状态编排器 —— 表现层与领域逻辑之间的唯一入口。
##
## 【层级】L3 单例（Autoload）
## 【职责】
##   1. 持有 L2 的 FarmGrid（全部农场规则与状态都在里面）
##   2. 把「操作成功」翻译成 EventBus 信号，广播给表现层
##   3. 订阅 day_changed，驱动作物每日生长
##
## 【为什么表现层只调这里】FarmView 是 3D 节点脚本，没法单测。
##   规则留在 FarmGrid / CropData，FarmView 只负责"把状态画出来"（见 DESIGN.md §4.1）。
##
## 【手持物纪律】`use_item()` 是鼠标左键的唯一入口，它只做一件事：
##   拿 `selected_entry()` 去分派。**不要让表现层自己判断"该翻地还是该浇水"** ——
##   那等于把规则搬到 3D 节点里，测试再也够不着。

const INITIAL_MONEY: int = 500
const MAX_STAMINA: int = 270
## 播种消耗的体力。工具的消耗写在 ToolData.stamina_cost 里（跟着工具走），
## 因为"同一件事换把工具代价不同"是工具的属性，不是编排层的属性。
const STAMINA_PLANT: int = 1

## 快捷栏按键动作（project.godot 里映射到 1…9、0、-、=）。
## 顺序即格位顺序：TOOL_ACTIONS[0] 对应第 1 格。
## 数量必须 == Hotbar.SLOT_COUNT，否则末几格没有快捷键 —— test_input_map.gd 会检查。
const TOOL_ACTIONS: Array[StringName] = [
	&"tool_1", &"tool_2", &"tool_3", &"tool_4", &"tool_5", &"tool_6",
	&"tool_7", &"tool_8", &"tool_9", &"tool_10", &"tool_11", &"tool_12",
]
## 调试用：按一下就过一天，省得等时钟
const ACTION_ADVANCE_DAY: StringName = &"debug_advance_day"

## 农场状态（L2）
var farm: FarmGrid = FarmGrid.new()
## 快捷栏布局（L2）：3 件工具 + 9 种种子
var hotbar: Hotbar = Hotbar.new()
var money: int = INITIAL_MONEY
var stamina: int = MAX_STAMINA

## 当前手持的格位下标（0 起）。开局是 0 号格 = 锄头 —— 第一天第一件事就是开垦。
var selected_slot: int = 0
## 收获产出数量的随机源（可 seed，便于复现）
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## 本局累计统计，调试用。类型化字典 ⇒ 取出即 int，无需转换。
var stats: Dictionary[String, int] = {"tilled": 0, "planted": 0, "harvested": 0, "days": 0}


func _ready() -> void:
	rng.randomize()
	# 作物生长挂在 day_ended（携带"刚结束那天"的天气），
	# 资源刷新挂在 day_changed（新一天已经开始）。两者职责不同，别合并。
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.day_changed.connect(_on_day_changed)


func _unhandled_input(event: InputEvent) -> void:
	# 注意：不能用 `event is InputEventKey and event.pressed` ——
	# `and` 链不会让分析器收窄 event 的类型，会报 "property not present"（属性不存在）。
	# 必须先单独判断类型，再取出强类型引用。
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return

	if event.is_action_pressed(ACTION_ADVANCE_DAY):
		TimeManager.sleep()
		get_viewport().set_input_as_handled()
		return

	var slot: int = slot_for_event(event)
	if slot >= 0:
		use_slot(slot)
		get_viewport().set_input_as_handled()


## 判断这个事件按下了第几格快捷栏（0 起）；没命中任何 tool_N 动作时返回 −1。
##
## 【为什么按动作名找，而不是直接减 KEY_1】动作是 project.godot 里的唯一事实来源。
##   写成 `keycode - KEY_1` 的话，输入映射表就变成了一份"看起来有用其实没人读"的摆设 ——
##   别人照着映射表改了键，游戏里毫无变化，会排查到怀疑人生。
##   走动作还有一个实际好处：将来做按键重绑定（Options 菜单）不用回来改这里。
##   代价是动作数量必须与格位数对得上 —— 由 test_input_map.gd 守着。
##
## 【为什么第 10~12 格是 0 / - / =】1…9 不够 12 格用。这是星露谷的老办法，
##   玩家的肌肉记忆里就有；比另发明一套（比如 F1~F3）更容易猜。
func slot_for_event(event: InputEvent) -> int:
	var index: int = 0
	while index < TOOL_ACTIONS.size():
		if event.is_action_pressed(TOOL_ACTIONS[index]):
			return index
		index += 1
	return -1


# ── 操作入口（表现层只调这几个）──────────────────────────

func till(cell: Vector2i) -> bool:
	if not farm.till(cell):
		return false
	stats["tilled"] = stats["tilled"] + 1
	EventBus.land_tilled.emit(cell)
	EventBus.tile_changed.emit(cell)
	return true


func water(cell: Vector2i) -> bool:
	if not farm.water(cell):
		return false
	EventBus.crop_watered.emit(cell)
	EventBus.tile_changed.emit(cell)
	return true


## 播种。crop_id 留空表示"用手上正拿着的种子"。
##
## 【为什么保留 crop_id 参数】测试和将来的"批量播种/系统自动补种"都需要
##   绕过手持物指定种子。传了 id 就以 id 为准。
func plant(cell: Vector2i, crop_id: String = "") -> bool:
	var id: String = crop_id if crop_id != "" else _held_seed_id()
	if id == "":
		# 手上不是种子 —— 这是合法状态（比如拿着锄头），不算错误
		return false
	var data: CropData = CropDatabase.get_crop(id)
	if data == null:
		return false
	# 季节白名单校验（规则在 L1 数据里，判断在 L3 编排里）
	if not data.grows_in_season(TimeManager.clock.season):
		return false
	if not farm.plant(cell, id):
		return false
	stats["planted"] = stats["planted"] + 1
	EventBus.crop_planted.emit(cell, id)
	EventBus.tile_changed.emit(cell)
	return true


## 收获。返回本次产出数量，0 表示没得收。
func harvest(cell: Vector2i) -> int:
	var tile: FarmTile = farm.peek(cell)
	if tile == null or not tile.has_crop():
		return 0
	var data: CropData = CropDatabase.get_crop(tile.crop_id)
	if data == null or not data.is_mature(tile.growth):
		return 0

	var crop_id: String = tile.crop_id
	if not farm.harvest(cell, data.mature_days):
		return 0

	var amount: int = rng.randi_range(data.yield_min, data.yield_max)
	stats["harvested"] = stats["harvested"] + amount

	# 一次性作物：收获后地变空但仍是已翻土；可再生作物：立刻重新长回幼苗
	if data.is_regrowable():
		farm.plant(cell, crop_id)
		var regrown: FarmTile = farm.peek(cell)
		if regrown != null:
			regrown.growth = maxi(0, data.mature_days - data.regrow_days)

	EventBus.crop_harvested.emit(cell, crop_id, amount)
	EventBus.tile_changed.emit(cell)
	return amount


## 鼠标左键入口：用手持物作用在格子上。
##
## 【核心规则 · M0.5 起】手持什么，就只能做什么：
##   格 1 锄头   → 只能翻地
##   格 2 洒水壶 → 只能浇水
##   格 3 镰刀   → 只能收割成熟作物
##   格 4+ 种子  → 只能播种
##
##   拿错工具时**不会"顺便帮你做了"**，而是明确告诉你该换哪件。
##   这是刻意的：M0 的「左键智能操作」虽然上手快，但快捷栏形同虚设 ——
##   手上拿什么跟能做什么毫无关系，玩家的选择没有意义。
##
## 【纪律】先校验、再扣体力、最后执行 —— 顺序不能反。
##   原来的写法是「先 _spend 再 plant」，而 plant 会因季节白名单失败，
##   结果就是「种不下去，但体力已经扣了，提示还写着体力不足」。
func use_item(cell: Vector2i) -> String:
	var entry: HotbarEntry = selected_entry()
	if entry == null or entry.is_empty():
		return "这一格是空的"
	if entry.is_tool():
		return _use_tool(cell, entry)
	if entry.is_seed():
		return _use_seed(cell, entry)
	return "无事可做"


func _use_tool(cell: Vector2i, entry: HotbarEntry) -> String:
	match entry.verb:
		ToolData.Verb.TILL:
			return _till_with(cell, entry)
		ToolData.Verb.WATER:
			return _water_with(cell, entry)
		ToolData.Verb.HARVEST:
			return _harvest_with(cell, entry)
	# 加了新工具却忘了在这里处理 —— 明说，而不是静默地什么都不发生
	return "%s 暂时用不了" % entry.label


func _till_with(cell: Vector2i, entry: HotbarEntry) -> String:
	var tile: FarmTile = farm.peek(cell)
	if tile != null and not tile.is_tillable():
		if tile.has_crop():
			return "这块地种着 %s" % _crop_name(tile.crop_id)
		return "这块地已经翻好了"
	if not _spend(_cost_of(entry)):
		return "体力不足"
	if till(cell):
		return "翻地"
	return "这里翻不了"


func _water_with(cell: Vector2i, entry: HotbarEntry) -> String:
	var tile: FarmTile = farm.peek(cell)
	if tile == null or tile.state == FarmTile.State.UNTILLED:
		return "要先用锄头翻地"
	if tile.state == FarmTile.State.WATERED:
		return "已经浇过水了"
	if not _spend(_cost_of(entry)):
		return "体力不足"
	if water(cell):
		return "浇水"
	return "这里不用浇水"


func _harvest_with(cell: Vector2i, entry: HotbarEntry) -> String:
	var tile: FarmTile = farm.peek(cell)
	if tile == null or not tile.has_crop():
		return "这里没有可以收割的作物"
	var data: CropData = CropDatabase.get_crop(tile.crop_id)
	if data == null:
		return "这里没有可以收割的作物"
	if not data.is_mature(tile.growth):
		return "%s 还要 %d 天" % [data.display_name, maxi(0, data.mature_days - tile.growth)]
	if not _spend(_cost_of(entry)):
		return "体力不足"
	var amount: int = harvest(cell)
	if amount <= 0:
		return "什么都没收到"
	add_money(amount * data.sell_price)
	return "收获 %s ×%d（+%d G）" % [data.display_name, amount, amount * data.sell_price]


func _use_seed(cell: Vector2i, entry: HotbarEntry) -> String:
	var tile: FarmTile = farm.peek(cell)
	if tile == null or tile.state == FarmTile.State.UNTILLED:
		return "要先用锄头翻地"
	if tile.has_crop():
		return "这块地种着 %s" % _crop_name(tile.crop_id)

	var seed: CropData = CropDatabase.get_crop(entry.id)
	if seed == null:
		return "无效的种子"
	# 季节白名单要在扣体力之前判 —— 否则"种不下去"还会白扣体力（见上面的纪律）
	if not seed.grows_in_season(TimeManager.clock.season):
		return "%s 不能在%s播种" % [seed.display_name, TimeManager.clock.season_name()]
	if not _spend(STAMINA_PLANT):
		return "体力不足"
	if plant(cell, entry.id):
		return "播种 %s" % seed.display_name
	return "这里种不下去"


## 工具的体力消耗跟着工具数据走（ToolData.stamina_cost）。
## 【为什么不把 cost 抄进 HotbarEntry】那样改一次数值要改两处。
##   工具表是唯一事实来源，HotbarEntry 只负责"显示什么"。
func _cost_of(entry: HotbarEntry) -> int:
	var tool: ToolData = ToolDatabase.get_tool(entry.id)
	return tool.stamina_cost if tool != null else 0


func _crop_name(crop_id: String) -> String:
	var data: CropData = CropDatabase.get_crop(crop_id)
	return data.display_name if data != null else crop_id


# ── 资源 ─────────────────────────────────────────────────

func _spend(amount: int) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	EventBus.stamina_changed.emit(stamina, MAX_STAMINA)
	return true


func add_money(amount: int) -> void:
	money += amount
	EventBus.money_changed.emit(money)


# ── 每日结算 ─────────────────────────────────────────────

## 【关键规则】作物每日生长挂在这里，而不是 day_changed。
## 参数里的 weather 是「刚刚结束这一天」的天气 ——
## 如果改成读 TimeManager.weather，拿到的会是新一天重掷后的天气，
## 导致"明天要下雨"变成"今天就长"。
func _on_day_ended(_day: int, _season: int, weather: int) -> void:
	var grown: Array[Vector2i] = farm.advance_day(weather, CropDatabase.get_crop)
	for cell: Vector2i in grown:
		EventBus.tile_changed.emit(cell)


## 新的一天已经开始：重置体力、累计统计。
func _on_day_changed(_day: int, _season: int) -> void:
	stats["days"] = stats["days"] + 1
	stamina = MAX_STAMINA
	EventBus.stamina_changed.emit(stamina, MAX_STAMINA)


# ── 手持格位 ─────────────────────────────────────────────

## 选中第 slot 格（0 起）。越界静默忽略 —— 越界不是错误，只是"按到了不存在的格"。
func use_slot(slot: int) -> void:
	if slot < 0 or slot >= hotbar.size():
		return
	selected_slot = slot
	EventBus.slot_selected.emit(selected_slot)


func selected_entry() -> HotbarEntry:
	return hotbar.entry_at(selected_slot)


## 手上如果是种子就返回对应的 CropData，是工具则返回 null。
##
## 【注意】调用方拿到 null 不等于出错 —— 拿着锄头时本来就没有"选中的种子"。
##   要判断"手上是工具还是种子"请用 `selected_entry().kind`。
func selected_crop() -> CropData:
	var entry: HotbarEntry = selected_entry()
	if entry == null or not entry.is_seed():
		return null
	return CropDatabase.get_crop(entry.id)


## 手上如果是工具就返回对应的 ToolData，是种子则返回 null。
func selected_tool() -> ToolData:
	var entry: HotbarEntry = selected_entry()
	if entry == null or not entry.is_tool():
		return null
	return ToolDatabase.get_tool(entry.id)


## 当前手持的种子 id；拿的不是种子就返回空串。
func _held_seed_id() -> String:
	var crop: CropData = selected_crop()
	return "" if crop == null else crop.id


## 手持物的显示名（"锄头" / "芜菁"）。空位返回空串。
func selected_label() -> String:
	var entry: HotbarEntry = selected_entry()
	return "" if entry == null else entry.label


## 按 id 切到某件工具。找不到返回 false（不改动当前手持）。
func select_tool(tool_id: String) -> bool:
	var index: int = hotbar.index_of_tool(tool_id)
	if index < 0:
		return false
	use_slot(index)
	return true


## 按 id 切到某种作物的种子。找不到返回 false。
func select_crop(crop_id: String) -> bool:
	var index: int = hotbar.index_of_crop(crop_id)
	if index < 0:
		return false
	use_slot(index)
	return true


# ── 存档 ─────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"farm": farm.to_dict(),
		"money": money,
		"stamina": stamina,
		"selected_slot": selected_slot,
	}


func from_dict(data: Dictionary) -> void:
	farm = FarmGrid.from_dict(VariantUtil.dict_dict(data, "farm"))
	money = VariantUtil.dict_int(data, "money", INITIAL_MONEY)
	stamina = VariantUtil.dict_int(data, "stamina", MAX_STAMINA)

	# 【旧档兼容】M0 存的是 selected_crop_id（当时快捷栏只有种子）。
	#   这里把老的作物 id 翻译成新布局里的格号，老档读进来手上还是原来那种种子。
	#   不清掉这个分支的代价是：老玩家的档一读进来手持物就跳回锄头，
	#   看起来像"读档把我的选择弄丢了"。
	var slot: int = VariantUtil.dict_int(data, "selected_slot", -1)
	if slot < 0:
		var legacy_id: String = VariantUtil.dict_str(data, "selected_crop_id", "")
		slot = hotbar.index_of_crop(legacy_id) if legacy_id != "" else -1
	selected_slot = clampi(slot, 0, maxi(0, hotbar.size() - 1))

	EventBus.money_changed.emit(money)
	EventBus.stamina_changed.emit(stamina, MAX_STAMINA)
	EventBus.slot_selected.emit(selected_slot)
