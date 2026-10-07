class_name ToolDatabase
extends RefCounted
## 工具数据表（按 id 查 ToolData）。
##
## 【层级】L1 数据层
## 【为什么不排序】`all_ids()` 的顺序 = 快捷栏前几格的顺序。
##   锄头必须占 1 号格：开局第一件事就是翻地，教具要放在最容易按到的位置。
##   （同样的坑在 CropDatabase 里踩过一次：按字母排序会把教学作物挤走，
##     详见 crop_database.gd 的 all_ids 注释。）
##
## 【为什么和 CropDatabase 分开】工具与作物是两种不同的东西：
##   作物有生长阶段、季节白名单、产量；工具只有"能做什么"。
##   硬塞进一张表会让两边字段都变得半数是空的。

const HOE: String = "hoe"
const CAN: String = "can"
const SICKLE: String = "sickle"

static var _cache: Dictionary[String, ToolData] = {}


static func _make(
	id: String,
	display_name: String,
	verb: ToolData.Verb,
	stamina_cost: int,
	icon_color: Color,
	hint: String,
) -> ToolData:
	var tool: ToolData = ToolData.new()
	tool.id = id
	tool.display_name = display_name
	tool.verb = verb
	tool.stamina_cost = stamina_cost
	tool.icon_color = icon_color
	tool.hint = hint
	return tool


static func _ensure_built() -> void:
	if not _cache.is_empty():
		return

	_cache[HOE] = _make(
		HOE, "锄头", ToolData.Verb.TILL, 2,
		Color(0.66, 0.46, 0.26), "开垦荒地",
	)
	_cache[CAN] = _make(
		CAN, "洒水壶", ToolData.Verb.WATER, 2,
		Color(0.46, 0.72, 0.88), "给土地浇水",
	)
	_cache[SICKLE] = _make(
		SICKLE, "镰刀", ToolData.Verb.HARVEST, 1,
		Color(0.82, 0.84, 0.86), "收割成熟作物",
	)


static func get_tool(id: String) -> ToolData:
	_ensure_built()
	if _cache.has(id):
		return _cache[id]
	return null


static func has_tool(id: String) -> bool:
	_ensure_built()
	return _cache.has(id)


## 全部工具 id，顺序 = 上面的声明顺序 = 快捷栏前几格的顺序。
static func all_ids() -> Array[String]:
	_ensure_built()
	var out: Array[String] = []
	for key: String in _cache:
		out.append(key)
	return out


## 开局默认手持的工具 —— 锄头。第一天第一件事就是开垦。
static func default_tool_id() -> String:
	return HOE
