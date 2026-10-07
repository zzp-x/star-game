class_name Hotbar
extends RefCounted
## 快捷栏的 12 格布局 + 按 id 反查格位。纯逻辑，GUT 可直接测。
##
## 【层级】L2 领域逻辑。与 FarmGrid 同一条纪律：
##   不引用 EventBus、不引用任何 Node。
##
## 【布局】前 3 格是工具，后 9 格是种子，正好 12 格：
##
##     格 1  格 2   格 3    │ 格 4 … 格 12
##     锄头  洒水壶  镰刀    │ 芜菁 … 蔓越莓（CropDatabase.all_ids() 顺序）
##
## 【为什么工具放最前面】玩家一天里锄头/水壶的使用频率远高于某一种种子，
##   而数字键 1 永远是最好按的那一个。教学作物芜菁顺位排到第 4。
##
## 【为什么用 12 格而不是"够用就行"】星露谷就是 12 格（数字键 1~9 加 0、-、=）。
##   12 格刚好装下 3 件工具 + 9 种作物，一格不浪费、也没有挤不下的风险。
##
## 【为什么不是 3 + 5】CropDatabase 现在有 9 种（春夏秋各若干），
##   少给格子会让秋季作物没地方放；而 SLOT_COUNT 是常量，改它要连着改
##   project.godot 的 tool_N 动作数量 —— 有 test_input_map.gd 守着。

const SLOT_COUNT: int = 12

var _entries: Array[HotbarEntry] = []


func _init() -> void:
	rebuild()


## 重新按数据表生成布局。数据表在运行期是只读的，正常只会走一次；
## 留着这个入口是为了测试能构造出"只有两种作物"的假布局。
func rebuild() -> void:
	_entries.clear()

	for tool_id: String in ToolDatabase.all_ids():
		if _entries.size() >= SLOT_COUNT:
			break
		_entries.append(HotbarEntry.make_tool(ToolDatabase.get_tool(tool_id)))

	for crop_id: String in CropDatabase.all_ids():
		if _entries.size() >= SLOT_COUNT:
			break
		_entries.append(HotbarEntry.make_seed(CropDatabase.get_crop(crop_id)))

	# 补齐空位：格子数必须是常量，否则"第 12 格"到底存不存在会随数据表变化，
	# HUD 的格位绘制与输入映射的对应关系就崩了。
	while _entries.size() < SLOT_COUNT:
		_entries.append(HotbarEntry.make_empty())


func size() -> int:
	return _entries.size()


## 取第 index 格。越界返回 null（调用方自己决定是忽略还是报错）。
func entry_at(index: int) -> HotbarEntry:
	if index < 0 or index >= _entries.size():
		return null
	return _entries[index]


## 全部格位（只读用途：HUD 绘制、测试遍历）。
func entries() -> Array[HotbarEntry]:
	return _entries.duplicate()


## 第一格工具的下标；正常是 0。
func first_tool_index() -> int:
	for i: int in _entries.size():
		if _entries[i].is_tool():
			return i
	return -1


## 第一格种子的下标 —— 即"种子的起始格号"。
func first_seed_index() -> int:
	for i: int in _entries.size():
		if _entries[i].is_seed():
			return i
	return -1


## 某工具在第几格；没有则 −1。
func index_of_tool(tool_id: String) -> int:
	for i: int in _entries.size():
		var entry: HotbarEntry = _entries[i]
		if entry.is_tool() and entry.id == tool_id:
			return i
	return -1


## 某种子在第几格；没有则 −1。
func index_of_crop(crop_id: String) -> int:
	for i: int in _entries.size():
		var entry: HotbarEntry = _entries[i]
		if entry.is_seed() and entry.id == crop_id:
			return i
	return -1
