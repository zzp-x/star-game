class_name CropGrowth
extends RefCounted
## 作物生长的纯算术：把「生长天数」换算成「阶段索引」与「视觉缩放」。
##
## 【层级】L2 领域逻辑 —— 零节点依赖，可直接 GUT 单测。
## 【存在理由】3D 素材包几乎不提供"同一作物的多个生长阶段模型"，
##   首版必须用「单模型 + 缩放」兜底。把插值算在这里，
##   将来换成真模型（stage_scenes）时只需替换 L4 的渲染分支，规则不动。

## 生长阶段数（含成熟阶段）。5 阶段 = 幼苗 / 小 / 中 / 大 / 成熟。
const STAGE_COUNT: int = 5

## 第 0 阶段（刚出芽）的视觉缩放
const MIN_SCALE: float = 0.35
## 成熟阶段的视觉缩放
const MAX_SCALE: float = 1.0


## 由生长天数推算阶段索引，范围 [0, STAGE_COUNT-1]。
static func stage_index(growth: int, mature_days: int) -> int:
	if mature_days <= 0:
		return STAGE_COUNT - 1
	if growth >= mature_days:
		return STAGE_COUNT - 1
	if growth <= 0:
		return 0
	var ratio: float = float(growth) / float(mature_days)
	# 用 floori() 而不是 int(floor())：Godot 的全局 floor() 返回签名是 Variant，
	# 传给 int() 会触发 unsafe_call_argument（本项目把它设成了 Error）。
	var index: int = floori(ratio * float(STAGE_COUNT))
	return clampi(index, 0, STAGE_COUNT - 1)


## 阶段的视觉缩放（线性插值 MIN_SCALE → MAX_SCALE）。
static func stage_scale(stage: int) -> float:
	var clamped: int = clampi(stage, 0, STAGE_COUNT - 1)
	var t: float = float(clamped) / float(STAGE_COUNT - 1)
	return MIN_SCALE + (MAX_SCALE - MIN_SCALE) * t


## 成熟进度 0.0 ~ 1.0，供 HUD 进度条使用。
static func progress(growth: int, mature_days: int) -> float:
	if mature_days <= 0:
		return 1.0
	return clampf(float(growth) / float(mature_days), 0.0, 1.0)
