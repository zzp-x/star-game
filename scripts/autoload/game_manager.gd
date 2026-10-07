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

const INITIAL_MONEY: int = 500
const MAX_STAMINA: int = 270
## 每种操作消耗的体力（见 DESIGN.md §3.6）
const STAMINA_TILL: int = 2
const STAMINA_WATER: int = 2
const STAMINA_PLANT: int = 1
const STAMINA_HARVEST: int = 1

## 农场状态（L2）
var farm: FarmGrid = FarmGrid.new()
var money: int = INITIAL_MONEY
var stamina: int = MAX_STAMINA

## 当前选中的种子 id，按 1–5 切换
var selected_crop_id: String = "parsnip"
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

	var slot: int = int(key.physical_keycode) - int(KEY_1)
	# 快捷栏有 12 格，但 M0 只有 9 种作物，所以 1~9 有效
	if slot >= 0 and slot < CropDatabase.all_ids().size():
		_select_crop_slot(slot)
		get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_F10:
		TimeManager.sleep()
		get_viewport().set_input_as_handled()


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


func plant(cell: Vector2i, crop_id: String = "") -> bool:
	var id: String = crop_id if crop_id != "" else selected_crop_id
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


## 只用鼠标左键一个键的「智能操作」，M0 手感验证用。
## 优先级：可收获 → 可播种 → 未翻地则翻地 → 已翻地未浇水则浇水
##
## 【纪律】先校验、再扣体力、最后执行 —— 顺序不能反。
##   原来的写法是「先 _spend 再 plant」，而 plant 会因季节白名单失败，
##   结果就是「种不下去，但体力已经扣了，提示还写着体力不足」。
func use_tool(cell: Vector2i) -> String:
	var tile: FarmTile = farm.peek(cell)

	# ① 成熟作物：收获
	if tile != null and tile.has_crop():
		var crop: CropData = CropDatabase.get_crop(tile.crop_id)
		if crop != null and crop.is_mature(tile.growth):
			if not _spend(STAMINA_HARVEST):
				return "体力不足"
			var amount: int = harvest(cell)
			if amount > 0:
				add_money(amount * crop.sell_price)
				return "收获 %s ×%d（+%d G）" % [crop.display_name, amount, amount * crop.sell_price]
			return "什么都没收到"

	# ② 未翻地：翻地
	if tile == null or tile.state == FarmTile.State.UNTILLED:
		if not _spend(STAMINA_TILL):
			return "体力不足"
		if till(cell):
			return "翻地"
		return "这里翻不了"

	# ③ 已翻地但空着：播种
	if tile.crop_id == "":
		var seed: CropData = selected_crop()
		if seed == null:
			return "没有选中的种子"
		# 季节白名单要在扣体力之前判 —— 否则"种不下去"还会白扣体力（见上面的纪律）
		if not seed.grows_in_season(TimeManager.clock.season):
			return "%s 不能在%s播种" % [seed.display_name, TimeManager.clock.season_name()]
		if not _spend(STAMINA_PLANT):
			return "体力不足"
		if plant(cell):
			return "播种 %s" % seed.display_name
		return "这里种不下去"

	# ④ 已播种但没浇水：浇水
	if tile.state == FarmTile.State.TILLED:
		if not _spend(STAMINA_WATER):
			return "体力不足"
		if water(cell):
			return "浇水"
		return "这里不用浇水"

	return "无事可做"


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


# ── 种子选择 ─────────────────────────────────────────────

func _select_crop_slot(slot: int) -> void:
	var ids: Array[String] = CropDatabase.all_ids()
	if slot < 0 or slot >= ids.size():
		return
	selected_crop_id = ids[slot]
	EventBus.crop_selected.emit(selected_crop_id)


func selected_crop() -> CropData:
	return CropDatabase.get_crop(selected_crop_id)


# ── 存档 ─────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"farm": farm.to_dict(),
		"money": money,
		"stamina": stamina,
		"selected_crop_id": selected_crop_id,
	}


func from_dict(data: Dictionary) -> void:
	farm = FarmGrid.from_dict(VariantUtil.dict_dict(data, "farm"))
	money = VariantUtil.dict_int(data, "money", INITIAL_MONEY)
	stamina = VariantUtil.dict_int(data, "stamina", MAX_STAMINA)
	selected_crop_id = VariantUtil.dict_str(data, "selected_crop_id", "parsnip")
	EventBus.money_changed.emit(money)
	EventBus.stamina_changed.emit(stamina, MAX_STAMINA)


## 一行摘要，调试与 HUD 都用它。
func describe(cell: Vector2i) -> String:
	var tile: FarmTile = farm.peek(cell)
	if tile == null:
		return "%s · 未生成" % str(cell)
	if tile.crop_id == "":
		return "%s · %s" % [str(cell), "荒草" if tile.state == FarmTile.State.UNTILLED else "已翻土"]
	var data: CropData = CropDatabase.get_crop(tile.crop_id)
	if data == null:
		return "%s · %s（未知作物）" % [str(cell), tile.crop_id]
	var state_text: String = "已浇水" if tile.state == FarmTile.State.WATERED else "未浇水"
	return "%s · %s %d/%d 天（%s）" % [str(cell), data.display_name, tile.growth, data.mature_days, state_text]
