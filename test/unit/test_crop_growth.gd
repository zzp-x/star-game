extends GutTest
## 作物生长阶段换算 + 作物数据表的单测。
##
## 【为什么值得测】3D 素材包几乎给不出"同一作物多个生长阶段模型"，
##   首版全靠「单模型 + 缩放」兜底。缩放插值一旦算错，
##   画面会出现"作物越长越小"或"缩进地里"，很难靠肉眼定位。

func test_stage_zero_at_planting() -> void:
	assert_eq(CropGrowth.stage_index(0, 4), 0, "刚播种是第 0 阶段")


func test_stage_max_at_maturity() -> void:
	assert_eq(CropGrowth.stage_index(4, 4), CropGrowth.STAGE_COUNT - 1, "成熟是最后阶段")


func test_stage_never_exceeds_max() -> void:
	assert_eq(CropGrowth.stage_index(999, 4), CropGrowth.STAGE_COUNT - 1, "超熟不应越界")


func test_stage_is_monotonic() -> void:
	var previous: int = -1
	for growth: int in range(0, 13):
		var stage: int = CropGrowth.stage_index(growth, 12)
		assert_true(stage >= previous, "生长天数增加时阶段不应回退")
		previous = stage


func test_zero_mature_days_counts_as_mature() -> void:
	assert_eq(CropGrowth.stage_index(0, 0), CropGrowth.STAGE_COUNT - 1)


func test_scale_grows_with_stage() -> void:
	var first: float = CropGrowth.stage_scale(0)
	var last: float = CropGrowth.stage_scale(CropGrowth.STAGE_COUNT - 1)
	assert_almost_eq(first, CropGrowth.MIN_SCALE, 0.001)
	assert_almost_eq(last, CropGrowth.MAX_SCALE, 0.001)
	assert_true(last > first, "成熟阶段应该比幼苗大")


func test_scale_clamps_out_of_range_stage() -> void:
	assert_almost_eq(CropGrowth.stage_scale(-5), CropGrowth.MIN_SCALE, 0.001)
	assert_almost_eq(CropGrowth.stage_scale(99), CropGrowth.MAX_SCALE, 0.001)


func test_progress() -> void:
	assert_almost_eq(CropGrowth.progress(0, 4), 0.0, 0.001)
	assert_almost_eq(CropGrowth.progress(2, 4), 0.5, 0.001)
	assert_almost_eq(CropGrowth.progress(9, 4), 1.0, 0.001, "进度应被钳制在 1.0")


# ── 作物数据表 ───────────────────────────────────────────

func test_database_has_parsnip() -> void:
	var crop: CropData = CropDatabase.get_crop("parsnip")
	assert_not_null(crop, "芜菁应该存在")
	assert_eq(crop.mature_days, 4, "芜菁 4 天成熟")
	assert_eq(crop.display_name, "芜菁")
	assert_true(crop.grows_in_season(Clock.SPRING), "芜菁是春季作物")


func test_unknown_crop_returns_null() -> void:
	assert_null(CropDatabase.get_crop("no_such_crop"), "未知作物应返回 null")


func test_spring_crops_are_available() -> void:
	var spring_crops: Array[CropData] = CropDatabase.crops_for_season(Clock.SPRING)
	assert_true(spring_crops.size() >= 5, "春季至少 5 种作物（见 §3.10）")


func test_winter_is_fallow() -> void:
	# 设计意图：冬季无经济作物（只剩采集与养殖），见 DESIGN.md §3.4 季节影响
	var winter: Array[CropData] = CropDatabase.crops_for_season(Clock.WINTER)
	assert_eq(winter.size(), 0, "冬季不应有可种作物")


func test_all_default_crops_are_well_formed() -> void:
	for id: String in CropDatabase.all_ids():
		var crop: CropData = CropDatabase.get_crop(id)
		assert_eq(crop.id, id, "%s 的 id 字段应与键一致" % id)
		assert_true(crop.mature_days > 0, "%s 的成熟天数必须为正" % id)
		assert_true(crop.yield_min >= 1, "%s 的产出下限至少为 1" % id)
		assert_true(crop.yield_max >= crop.yield_min, "%s 的产出区间上下限颠倒" % id)
