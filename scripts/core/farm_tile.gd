class_name FarmTile
extends RefCounted
## 农场单个格子的状态。纯数据 + 纯逻辑，无节点依赖、无维度依赖。
##
## 【格位表示】用 Vector2i（x = 东西方向，y = 南北方向）。
## 这就是「同一份农场逻辑能同时跑在 2D 和 3D 上」的原因 —— 见 DESIGN.md §4.1。

enum State {
	UNTILLED = 0,  ## 荒草 / 未开垦
	TILLED = 1,    ## 已翻土
	WATERED = 2,   ## 已浇水 —— 每天清晨重置回 TILLED
}

## 格位坐标
var cell: Vector2i = Vector2i.ZERO
## 土地状态，取值见 State
var state: int = State.UNTILLED
## 种在这里的作物 id（空串表示没种）
var crop_id: String = ""
## 已生长天数
var growth: int = 0
## 是否已枯死（季节错配等）
var dead: bool = false


func has_crop() -> bool:
	return crop_id != "" and not dead


func is_tillable() -> bool:
	return state == State.UNTILLED and crop_id == ""


func is_watered() -> bool:
	return state == State.WATERED


## 是否已成熟。mature_days 由 CropData 提供（规则不写在格子里，见 DESIGN.md §4.5）。
func is_mature(mature_days: int) -> bool:
	return has_crop() and growth >= mature_days


func clear_crop() -> void:
	crop_id = ""
	growth = 0
	dead = false


func to_dict() -> Dictionary:
	return {
		"state": state,
		"crop": crop_id,
		"growth": growth,
		"dead": dead,
	}


static func from_dict(cell_pos: Vector2i, data: Dictionary) -> FarmTile:
	var tile: FarmTile = FarmTile.new()
	tile.cell = cell_pos
	tile.state = VariantUtil.dict_int(data, "state", State.UNTILLED)
	tile.crop_id = VariantUtil.dict_str(data, "crop", "")
	tile.growth = VariantUtil.dict_int(data, "growth", 0)
	tile.dead = VariantUtil.dict_bool(data, "dead", false)
	return tile
