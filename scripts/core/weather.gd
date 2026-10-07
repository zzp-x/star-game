class_name Weather
extends RefCounted
## 天气类型与权重表。
##
## 【层级】L2 领域逻辑 —— 零节点依赖，可在 GUT 中直接断言。
## 【纪律】所有游戏规则都写在 L2/L3，绝不写进场景脚本（见 DESIGN.md §4.1）。

enum Kind {
	SUNNY = 0,  ## 晴
	RAIN = 1,   ## 雨 —— 自动浇水
	STORM = 2,  ## 暴风 —— 雨 + 雷电
	SNOW = 3,   ## 雪 —— 冬季专属，自动浇水
	FOG = 4,    ## 雾 —— 降低能见度
}

const SUNNY: int = Kind.SUNNY
const RAIN: int = Kind.RAIN
const STORM: int = Kind.STORM
const SNOW: int = Kind.SNOW
const FOG: int = Kind.FOG

const NAMES: Array[String] = ["晴", "雨", "暴风", "雪", "雾"]

## 每季的天气权重表，顺序与 Kind 一致。
## 规则：冬天只下雪不下雨（雪的权重远高于其它季节）。
static func weights_for_season(season: int) -> PackedInt32Array:
	match season:
		0:
			return PackedInt32Array([50, 30, 5, 0, 15])
		1:
			return PackedInt32Array([70, 15, 5, 0, 10])
		2:
			return PackedInt32Array([55, 25, 5, 0, 15])
		3:
			return PackedInt32Array([45, 0, 5, 45, 5])
	return PackedInt32Array([50, 30, 5, 0, 15])

## 该天气是否会自动给作物浇水（省一次体力）。
static func waters_crops(kind: int) -> bool:
	return kind == Kind.RAIN or kind == Kind.STORM or kind == Kind.SNOW

## 按季节权重随机掷一次天气。天气在每天早上重掷（见 TimeManager）。
static func roll(season: int, rng: RandomNumberGenerator) -> int:
	var weights: PackedInt32Array = weights_for_season(season)
	var total: int = 0
	for w: int in weights:
		total += w
	if total <= 0:
		return Kind.SUNNY
	var pick: int = rng.randi_range(1, total)
	var acc: int = 0
	for i: int in range(weights.size()):
		acc += weights[i]
		if pick <= acc:
			return i
	return Kind.SUNNY

static func name_of(kind: int) -> String:
	if kind < 0 or kind >= NAMES.size():
		return "未知"
	return NAMES[kind]
