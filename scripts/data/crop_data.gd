class_name CropData
extends Resource
## 作物静态数据。一处改动全局生效。
##
## 【层级】L1 数据层 —— 纯数据，不含游戏规则。
## 【M1 计划】改为 res://data/crops/*.tres，在 Inspector 里可视化编辑。
## 【3D 特有关键字段】stage_scenes / stage_scales，见 DESIGN.md §6.4 作物生长阶段对策。

@export var id: String = ""
@export var display_name: String = ""
## 可种植季节（取值见 Clock.Season）。留空 = 全季节可种。
@export var seasons: Array[int] = []
## 从播种到成熟需要的生长天数
@export var mature_days: int = 4
## 收获后可再生的间隔天数。0 = 一次性作物（收获后地变空）
@export var regrow_days: int = 0
@export var seed_price: int = 0
@export var sell_price: int = 0
@export var yield_min: int = 1
@export var yield_max: int = 1

## ★ 首选：各生长阶段的完整模型场景（若素材包提供）
@export var stage_scenes: Array[PackedScene] = []
## ★ 兜底：素材包不提供多阶段模型时，用同一模型 + 缩放模拟生长
@export var stage_scales: Array[float] = []


## 是否已达到成熟天数。
func is_mature(growth: int) -> bool:
	return growth >= mature_days


func grows_in_season(season: int) -> bool:
	if seasons.is_empty():
		return true
	return seasons.has(season)


func is_regrowable() -> bool:
	return regrow_days > 0


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"seasons": seasons,
		"mature_days": mature_days,
		"regrow_days": regrow_days,
		"seed_price": seed_price,
		"sell_price": sell_price,
		"yield_min": yield_min,
		"yield_max": yield_max,
	}
