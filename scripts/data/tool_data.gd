class_name ToolData
extends Resource
## 工具静态数据（锄头 / 洒水壶 / 镰刀）。
##
## 【层级】L1 数据层 —— 纯数据，不含任何游戏规则判断。
##
## 【为什么要"工具"这一层】M0 最初是「左键智能操作」：点一下自动判断该翻地、
##   该播种还是该浇水。这样上手最快，但**玩家的选择没有意义** ——
##   快捷栏只是个摆设，手上拿什么跟能做什么毫无关系。
##   M0.5 起改为「手持什么才能做什么」：锄头只能翻地、水壶只能浇水、
##   镰刀只能收割、种子只能播种。规则简单到一句话讲得清，
##   但每一格快捷栏立刻有了重量（见 docs/DESIGN.md §3.11）。

## 工具能做的事。**它不是"工具类型"，而是"这个动作"** ——
## 所以判断逻辑写成 `match verb`，将来加新工具只要复用已有的 verb 即可
## （比如"大锄头"和"小锄头"共用 TILL，只是消耗体力不同）。
enum Verb {
	TILL,     ## 翻地
	WATER,    ## 浇水
	HARVEST,  ## 收割成熟作物
}

@export var id: String = ""
@export var display_name: String = ""
@export var verb: Verb = Verb.TILL
## 使用一次消耗的体力
@export var stamina_cost: int = 2
## 图标代表色。和 CropData.icon_color 同一套零素材方案：M0.5 用它给
## 程序化图标上色，M2 换成贴图后它退化为兜底色。
@export var icon_color: Color = Color.WHITE
## 一句话用途说明，出现在快捷栏上方的"手持物"标签里
@export var hint: String = ""
