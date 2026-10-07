extends GutTest
## FarmGrid 核心规则单测。
##
## 【关键点】这些测试**不启动场景树、不渲染任何东西、不需要素材** ——
##   直接 `FarmGrid.new()` 然后断言。
##   这正是把游戏规则放进 L2 纯逻辑层的回报（见 DESIGN.md §4.1）：
##   在 3D 里"手动验证一遍作物生长"要走到田里、等太阳升起、看动画，
##   而这里只需要 0.01 秒。

var _grid: FarmGrid
var _lookup: Callable

const PARSNIP_DAYS: int = 4  # CropDatabase 里芜菁的成熟天数


func before_each() -> void:
	_grid = FarmGrid.new()
	_lookup = CropDatabase.get_crop


# ── 基础状态 ─────────────────────────────────────────────

func test_new_cell_is_untilled() -> void:
	var tile: FarmTile = _grid.get_or_create(Vector2i(0, 0))
	assert_eq(tile.state, FarmTile.State.UNTILLED, "新格子应该是荒地")
	assert_eq(tile.crop_id, "", "新格子没有作物")
	assert_eq(tile.growth, 0, "新格子生长天数为 0")


func test_peek_does_not_create() -> void:
	assert_null(_grid.peek(Vector2i(9, 9)), "peek 不应创建格子")
	assert_eq(_grid.tile_count(), 0)


# ── 翻地 ─────────────────────────────────────────────────

func test_till_then_till_again_is_rejected() -> void:
	assert_true(_grid.till(Vector2i(0, 0)), "荒地应该能翻")
	assert_false(_grid.till(Vector2i(0, 0)), "已翻土的格子不能重复翻")


func test_bounds_are_enforced() -> void:
	var bounded: FarmGrid = FarmGrid.new(4, 4)
	assert_true(bounded.in_bounds(Vector2i(0, 0)))
	assert_true(bounded.in_bounds(Vector2i(3, 3)))
	assert_false(bounded.in_bounds(Vector2i(4, 0)), "x 越界")
	assert_false(bounded.in_bounds(Vector2i(-1, 0)), "x 负值越界")
	assert_false(bounded.in_bounds(Vector2i(0, 4)), "y 越界")
	assert_false(bounded.till(Vector2i(9, 9)), "越界格子不能翻")


func test_default_grid_is_unbounded() -> void:
	assert_true(_grid.in_bounds(Vector2i(999, -999)), "未指定尺寸时不限制边界")


# ── 播种 ─────────────────────────────────────────────────

func test_plant_requires_tilled_soil() -> void:
	assert_false(_grid.plant(Vector2i(1, 1), "parsnip"), "荒地不能直接播种")


func test_plant_twice_is_rejected() -> void:
	var cell: Vector2i = Vector2i(1, 1)
	_grid.till(cell)
	assert_true(_grid.plant(cell, "parsnip"))
	assert_false(_grid.plant(cell, "potato"), "同一格不能种第二株")


# ── 浇水 ─────────────────────────────────────────────────

func test_water_untilled_is_rejected() -> void:
	assert_false(_grid.water(Vector2i(5, 5)), "荒地不能浇水")


func test_water_twice_is_rejected() -> void:
	var cell: Vector2i = Vector2i(5, 5)
	_grid.till(cell)
	assert_true(_grid.water(cell))
	assert_false(_grid.water(cell), "已浇水的格子重复浇无效")
	assert_eq(_grid.peek(cell).state, FarmTile.State.WATERED)


# ── ★ 核心规则：只有浇过水才生长 ──────────────────────────

func test_unwatered_crop_does_not_grow() -> void:
	var cell: Vector2i = Vector2i(3, 4)
	_grid.till(cell)
	_grid.plant(cell, "parsnip")

	var grown: Array[Vector2i] = _grid.advance_day(Weather.SUNNY, _lookup)

	assert_eq(_grid.peek(cell).growth, 0, "没浇水就不该生长")
	assert_eq(grown.size(), 0, "没有格子应该被标记为生长")


func test_watered_crop_grows_one_day() -> void:
	var cell: Vector2i = Vector2i(3, 4)
	_grid.till(cell)
	_grid.plant(cell, "parsnip")
	_grid.water(cell)

	var grown: Array[Vector2i] = _grid.advance_day(Weather.SUNNY, _lookup)

	assert_eq(_grid.peek(cell).growth, 1, "浇过水应该生长 1 天")
	assert_true(grown.has(cell), "生长列表里应该有这一格")


func test_rain_auto_waters() -> void:
	var cell: Vector2i = Vector2i(3, 4)
	_grid.till(cell)
	_grid.plant(cell, "parsnip")

	_grid.advance_day(Weather.RAIN, _lookup)

	assert_eq(_grid.peek(cell).growth, 1, "下雨应该自动浇水并生长 1 天")


func test_snow_also_waters() -> void:
	var cell: Vector2i = Vector2i(3, 4)
	_grid.till(cell)
	_grid.plant(cell, "parsnip")

	_grid.advance_day(Weather.SNOW, _lookup)

	assert_eq(_grid.peek(cell).growth, 1, "下雪也应该自动浇水")


func test_watering_resets_each_day() -> void:
	var cell: Vector2i = Vector2i(3, 4)
	_grid.till(cell)
	_grid.plant(cell, "parsnip")
	_grid.water(cell)
	assert_eq(_grid.peek(cell).state, FarmTile.State.WATERED)

	_grid.advance_day(Weather.SUNNY, _lookup)
	assert_eq(_grid.peek(cell).state, FarmTile.State.TILLED, "第二天浇水状态应重置")

	# 重置之后不再生长 —— 这是"必须每天浇水"的手感来源
	_grid.advance_day(Weather.SUNNY, _lookup)
	assert_eq(_grid.peek(cell).growth, 1, "重置后没再浇水，不应继续生长")


func test_mature_crop_stops_counting_growth() -> void:
	var cell: Vector2i = Vector2i(0, 0)
	_grid.till(cell)
	_grid.plant(cell, "parsnip")

	for i: int in range(PARSNIP_DAYS + 6):
		_grid.water(cell)
		_grid.advance_day(Weather.SUNNY, _lookup)

	assert_eq(_grid.peek(cell).growth, PARSNIP_DAYS, "成熟后生长天数不应继续累加")


# ── 收获 ─────────────────────────────────────────────────

func test_harvest_requires_maturity() -> void:
	var cell: Vector2i = Vector2i(2, 2)
	_grid.till(cell)
	_grid.plant(cell, "parsnip")

	assert_false(_grid.harvest(cell, PARSNIP_DAYS), "未成熟不能收获")

	for i: int in range(PARSNIP_DAYS):
		_grid.water(cell)
		_grid.advance_day(Weather.SUNNY, _lookup)

	assert_true(_grid.harvest(cell, PARSNIP_DAYS), "成熟后应该能收获")


func test_harvest_clears_crop_but_keeps_tilled() -> void:
	var cell: Vector2i = Vector2i(2, 2)
	_grid.till(cell)
	_grid.plant(cell, "parsnip")
	for i: int in range(PARSNIP_DAYS):
		_grid.water(cell)
		_grid.advance_day(Weather.SUNNY, _lookup)
	_grid.harvest(cell, PARSNIP_DAYS)

	var tile: FarmTile = _grid.peek(cell)
	assert_eq(tile.crop_id, "", "收获后地变空")
	assert_eq(tile.growth, 0, "生长天数归零")
	assert_eq(tile.state, FarmTile.State.TILLED, "收获后仍是已翻土，可以直接再种")


func test_harvest_empty_cell_returns_false() -> void:
	assert_false(_grid.harvest(Vector2i(7, 7), PARSNIP_DAYS), "空地上不能收获")


# ── 序列化 ───────────────────────────────────────────────

func test_serialize_round_trip() -> void:
	var cell: Vector2i = Vector2i(2, 3)
	_grid.till(cell)
	_grid.plant(cell, "potato")
	_grid.water(cell)

	var restored: FarmGrid = FarmGrid.from_dict(_grid.to_dict())
	var tile: FarmTile = restored.peek(cell)

	assert_not_null(tile, "读档后格子应该还在")
	assert_eq(tile.crop_id, "potato")
	assert_eq(tile.state, FarmTile.State.WATERED)
	assert_eq(tile.growth, 0)


func test_untouched_tiles_are_not_serialized() -> void:
	_grid.get_or_create(Vector2i(0, 0))
	_grid.till(Vector2i(1, 1))

	var data: Dictionary = _grid.to_dict()
	var tiles: Dictionary = VariantUtil.dict_dict(data, "tiles")
	assert_eq(tiles.size(), 1, "完全空白的格子不应写进存档")
