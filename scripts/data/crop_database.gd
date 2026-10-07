class_name CropDatabase
extends RefCounted
## 作物数据表（按 id 查 CropData）。
##
## 【M0 说明】先用代码内置定义 —— 保证「零素材、零 .tres」也能跑通玩法与单测。
## 【M1 计划】改为扫描 res://data/crops/*.tres（Inspector 可视化编辑），
##            本类退化为纯缓存 + 查找，接口不变。
##
## 【为什么不用 .tres】M0 的目标是「第一天就能 F5 跑起来、测试全绿」。
## 手写 .tres 会引入 uid / format 版本等无关风险，也可能拖慢第一步。

## 【类型化字典】取出元素时直接就是 CropData，不是 Variant ——
## 这样项目才能把 unsafe_* 警告设成 Error。
static var _cache: Dictionary[String, CropData] = {}


static func _make(
	id: String,
	display_name: String,
	seasons: Array[int],
	mature_days: int,
	regrow_days: int,
	seed_price: int,
	sell_price: int,
	yield_min: int = 1,
	yield_max: int = 1,
	icon_color: Color = Color(0.42, 0.68, 0.32),
) -> CropData:
	var crop: CropData = CropData.new()
	crop.id = id
	crop.display_name = display_name
	crop.seasons = seasons
	crop.mature_days = mature_days
	crop.regrow_days = regrow_days
	crop.seed_price = seed_price
	crop.sell_price = sell_price
	crop.yield_min = yield_min
	crop.yield_max = yield_max
	crop.icon_color = icon_color
	return crop


static func _ensure_built() -> void:
	if not _cache.is_empty():
		return
	var spring: Array[int] = [Clock.SPRING]
	var summer: Array[int] = [Clock.SUMMER]
	var fall: Array[int] = [Clock.FALL]

	# ── 春季（5 种，见 DESIGN.md §3.10「一季作物数 = 5」）──
	_cache["parsnip"] = _make("parsnip", "芜菁", spring, 4, 0, 20, 35, 1, 1, Color(0.94, 0.89, 0.72))
	_cache["cauliflower"] = _make("cauliflower", "花椰菜", spring, 12, 0, 80, 175, 1, 1, Color(0.92, 0.95, 0.86))
	_cache["potato"] = _make("potato", "土豆", spring, 6, 0, 50, 80, 1, 3, Color(0.74, 0.58, 0.35))
	_cache["green_bean"] = _make("green_bean", "四季豆", spring, 10, 3, 60, 40, 1, 2, Color(0.36, 0.68, 0.32))
	_cache["strawberry"] = _make("strawberry", "草莓", spring, 8, 4, 100, 120, 1, 1, Color(0.88, 0.24, 0.28))

	# ── 夏 / 秋（各 2 种，M1 补全到 5）──
	_cache["melon"] = _make("melon", "甜瓜", summer, 12, 0, 80, 250, 1, 1, Color(0.66, 0.86, 0.45))
	_cache["blueberry"] = _make("blueberry", "蓝莓", summer, 13, 4, 80, 50, 3, 3, Color(0.37, 0.42, 0.82))
	_cache["pumpkin"] = _make("pumpkin", "南瓜", fall, 13, 0, 100, 320, 1, 1, Color(0.93, 0.53, 0.16))
	_cache["cranberry"] = _make("cranberry", "蔓越莓", fall, 7, 5, 240, 75, 2, 2, Color(0.76, 0.16, 0.24))


## 按 id 取作物。找不到返回 null（调用方需处理）。
static func get_crop(id: String) -> CropData:
	_ensure_built()
	if _cache.has(id):
		return _cache[id]
	return null


static func has_crop(id: String) -> bool:
	_ensure_built()
	return _cache.has(id)


## 全部作物 id，顺序 = `_ensure_built()` 里的声明顺序。
##
## 【为什么不排序】快捷栏的格位顺序、数字键 1~9 各对应哪种作物，都由这个顺序决定。
##   声明顺序是"春 → 夏 → 秋、由便宜到贵"，所以教学作物芜菁正好是 1 号格；
##   按字母排序的话芜菁会掉到第 6 格，按 1 选出来的却是夏作物的蓝莓 ——
##   玩家开局就会按 1，然后怎么种都种不下去，还以为游戏坏了。
##   （Godot 的 Dictionary 保证按插入顺序遍历，这个前提是可靠的。）
static func all_ids() -> Array[String]:
	_ensure_built()
	var out: Array[String] = []
	for key: String in _cache:
		out.append(key)
	return out


## 某季节可种的作物列表。留空 seasons 视为全季节可种。
static func crops_for_season(season: int) -> Array[CropData]:
	_ensure_built()
	var out: Array[CropData] = []
	for key: String in _cache:
		var crop: CropData = _cache[key]
		if crop.grows_in_season(season):
			out.append(crop)
	return out


## 主场景要用的「默认种子」——M0 按 1 键播它。
static func default_crop() -> CropData:
	return get_crop("parsnip")
