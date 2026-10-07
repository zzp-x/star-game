class_name HotbarEntry
extends RefCounted
## 快捷栏的一格 —— 纯结构，不含任何查表或规则判断。
##
## 【层级】L2 领域逻辑（只被 Hotbar 构造，自身零依赖）
##
## 【为什么把显示文案"抄"进这一格里】快捷栏每帧都要重绘，
##   在 _draw 里现查数据表既啰嗦又容易写出 unsafe 调用。
##   构造时抄一份，之后这一格就是自解释的。
##
## 【为什么不直接存 CropData / ToolData 引用】那样 UI 会顺手去读
##   `entry.crop.mature_days`，慢慢把规则判断漏到表现层。
##   这里只暴露"显示什么"，逼调用方要用规则时回 GameManager。

enum Kind {
	EMPTY,  ## 空位
	TOOL,   ## 工具（锄头 / 洒水壶 / 镰刀）
	SEED,   ## 种子（对应一种作物）
}

var kind: Kind = Kind.EMPTY
## 工具 id 或作物 id；EMPTY 时为空串
var id: String = ""
## 显示名（"锄头" / "芜菁"）
var label: String = ""
## 图标代表色
var color: Color = Color.WHITE
## 只有 TOOL 有意义：取值见 ToolData.Verb；其余为 −1
var verb: int = -1
## 只有 SEED 有意义：这种作物可以播种的季节（空 = 全季节）
var seasons: Array[int] = []


static func make_empty() -> HotbarEntry:
	return HotbarEntry.new()


static func make_tool(tool: ToolData) -> HotbarEntry:
	var entry: HotbarEntry = HotbarEntry.new()
	if tool == null:
		return entry
	entry.kind = Kind.TOOL
	entry.id = tool.id
	entry.label = tool.display_name
	entry.color = tool.icon_color
	entry.verb = tool.verb
	return entry


static func make_seed(crop: CropData) -> HotbarEntry:
	var entry: HotbarEntry = HotbarEntry.new()
	if crop == null:
		return entry
	entry.kind = Kind.SEED
	entry.id = crop.id
	entry.label = crop.display_name
	entry.color = crop.icon_color
	entry.seasons = crop.seasons.duplicate()
	return entry


func is_empty() -> bool:
	return kind == Kind.EMPTY


func is_tool() -> bool:
	return kind == Kind.TOOL


func is_seed() -> bool:
	return kind == Kind.SEED


## 这种子在当前季节能不能种。
## 【为什么留空 seasons 算"能种"】和 CropData.grows_in_season 同一条规则 ——
##   规则只有一处实现，这里只是把它套到一格的字段上（避免为了判一次季节去查表）。
func grows_in_season(season: int) -> bool:
	if seasons.is_empty():
		return true
	return seasons.has(season)
