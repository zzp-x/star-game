class_name FarmGrid
extends RefCounted
## 农场土地状态机 —— 全部游戏规则都在这里。
##
## 【层级】L2 领域逻辑。零节点依赖、零维度依赖、**零信号**。
##   · 不引用 EventBus（那是 L3 的事）—— 操作成功与否用 bool / int 返回。
##   · 不引用任何 Node / GridMap / 模型 —— 表现层订阅信号后自行刷新。
##
## 【为什么这样切】把规则从 3D 节点里抽出来，GUT 才能直接
##   `FarmGrid.new()` 然后断言，不需要启动场景树、不需要渲染任何东西。
##   在 3D 里"手动验证一遍"的成本远高于 2D（要走到田里、要等太阳升起）。
##
## 【本类负责的规则】
##   · 翻地 / 浇水 / 播种 / 收获的前置条件
##   · 「只有浇过水（或下雨下雪）的作物才生长」
##   · 「浇水状态每天清晨重置」

## 农场尺寸。0 表示该方向不限制（M0 阶段先不限制）。
var width: int = 0
var height: int = 0

## 格位 → FarmTile。
## 【为什么用「类型化字典」】`Dictionary[Vector2i, FarmTile]` 取出元素时就是 FarmTile，
##   而不是 Variant —— 这让项目能把 unsafe_* 警告设成 Error 而不牺牲可读性。
##   另外用向量做键，天然与 2D/3D 无关。
var _tiles: Dictionary[Vector2i, FarmTile] = {}


func _init(p_width: int = 0, p_height: int = 0) -> void:
	width = p_width
	height = p_height


# ── 查询 ─────────────────────────────────────────────────

func in_bounds(cell: Vector2i) -> bool:
	if width > 0 and (cell.x < 0 or cell.x >= width):
		return false
	if height > 0 and (cell.y < 0 or cell.y >= height):
		return false
	return true


func has_tile(cell: Vector2i) -> bool:
	return _tiles.has(cell)


## 取出格子，不存在则新建一个（默认是未开垦）。
func get_or_create(cell: Vector2i) -> FarmTile:
	if not _tiles.has(cell):
		var tile: FarmTile = FarmTile.new()
		tile.cell = cell
		_tiles[cell] = tile
	return _tiles[cell]


## 只读查询，不存在则返回 null（不会创建）。
func peek(cell: Vector2i) -> FarmTile:
	if _tiles.has(cell):
		return _tiles[cell]
	return null


func tile_count() -> int:
	return _tiles.size()


func all_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for key: Vector2i in _tiles:
		out.append(key)
	return out


## 已种下的作物总数，便于 HUD 显示。
func planted_count() -> int:
	var n: int = 0
	for key: Vector2i in _tiles:
		var tile: FarmTile = _tiles[key]
		if tile.has_crop():
			n += 1
	return n


# ── 操作（返回 false / 0 表示操作无效）─────────────────────

## 翻地。仅未开垦且无作物的格子可以翻。
func till(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	var tile: FarmTile = get_or_create(cell)
	if not tile.is_tillable():
		return false
	tile.state = FarmTile.State.TILLED
	return true


## 浇水。未开垦的格子不能浇；已浇过的重复浇无效。
func water(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	var tile: FarmTile = get_or_create(cell)
	if tile.state != FarmTile.State.TILLED:
		return false
	tile.state = FarmTile.State.WATERED
	return true


## 播种。必须在已翻土的格子上，且该格没有作物。
func plant(cell: Vector2i, crop_id: String) -> bool:
	if not in_bounds(cell):
		return false
	var tile: FarmTile = get_or_create(cell)
	if tile.state == FarmTile.State.UNTILLED:
		return false
	if tile.crop_id != "":
		return false
	tile.crop_id = crop_id
	tile.growth = 0
	tile.dead = false
	return true


## 收获。返回本次产出数量，0 表示没得收。
## 【注意】产出数量的随机部分由 L3 GameManager 处理，保持本类可确定性单测。
func harvest(cell: Vector2i, mature_days: int) -> bool:
	if not in_bounds(cell):
		return false
	var tile: FarmTile = peek(cell)
	if tile == null or not tile.is_mature(mature_days):
		return false
	tile.clear_crop()
	return true


## 把某格恢复成荒地（清理作物 + 除草）。
func clear_tile(cell: Vector2i) -> void:
	if not in_bounds(cell):
		return
	var tile: FarmTile = peek(cell)
	if tile == null:
		return
	tile.clear_crop()
	tile.state = FarmTile.State.UNTILLED


# ── 每日推进（核心规则）──────────────────────────────────

## 每天清晨推进一次。
##
## 规则：
##   1. 只有**浇过水**的格子（或当天雨 / 暴风 / 雪）作物才生长；
##   2. 已成熟的作物不再累计生长天数；
##   3. 推进后，浇水状态一律重置回「已翻土」。
##
## lookup: Callable(crop_id: String) -> CropData，用于取成熟天数。
## 返回本次真正生长了的格位列表，供 L4 做增量刷新。
func advance_day(weather: int, lookup: Callable) -> Array[Vector2i]:
	var rained: bool = Weather.waters_crops(weather)
	var grown: Array[Vector2i] = []

	for key: Vector2i in _tiles:
		var tile: FarmTile = _tiles[key]

		if tile.has_crop():
			var crop: CropData = VariantUtil.to_crop_data(lookup.call(tile.crop_id))
			if crop != null and not crop.is_mature(tile.growth):
				if rained or tile.state == FarmTile.State.WATERED:
					tile.growth += 1
					grown.append(key)

		# 浇水状态每天清晨重置（规则 3）
		if tile.state == FarmTile.State.WATERED:
			tile.state = FarmTile.State.TILLED

	return grown


# ── 序列化 ───────────────────────────────────────────────

## 键格式 "x,y"（不是 Vector2i 直接序列化），保证 JSON 可读、跨版本稳定。
func to_dict() -> Dictionary:
	var tiles: Dictionary = {}
	for key: Vector2i in _tiles:
		var tile: FarmTile = _tiles[key]
		if tile.state == FarmTile.State.UNTILLED and tile.crop_id == "" and tile.growth == 0:
			continue  # 完全空白的格子不写进存档
		tiles["%d,%d" % [key.x, key.y]] = tile.to_dict()
	return {
		"width": width,
		"height": height,
		"tiles": tiles,
	}


static func from_dict(data: Dictionary) -> FarmGrid:
	var grid: FarmGrid = FarmGrid.new(
		VariantUtil.dict_int(data, "width", 0),
		VariantUtil.dict_int(data, "height", 0),
	)
	var tiles: Dictionary = VariantUtil.dict_dict(data, "tiles")
	for key: Variant in tiles:
		var parts: PackedStringArray = VariantUtil.to_str(key).split(",")
		if parts.size() != 2:
			continue
		var pos: Vector2i = Vector2i(int(parts[0]), int(parts[1]))
		var tile_data: Dictionary = VariantUtil.to_dict(tiles[key])
		grid._tiles[pos] = FarmTile.from_dict(pos, tile_data)
	return grid
