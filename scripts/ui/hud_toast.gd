class_name HudToast
extends PanelContainer
## 一条屏幕消息（"翻地""播种 芜菁""体力不足"…）。
##
## 【层级】L4 表现层
## 【为什么做成独立组件而不是在 HUD 里用字典记账】
##   消息条要「自己活一段时间后淡出并销毁」。让组件自己管生命周期，
##   HUD 只需要维护一个列表并在超出上限时丢掉最老的 ——
##   比在 HUD 里同时维护「节点 → 剩余时间」两张表干净得多，
##   也不会出现节点已销毁但记录还在的悬空引用。

## 存活秒数
const LIFE: float = 2.8
## 最后这几秒用来淡出
const FADE: float = 0.6

var _life: float = LIFE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	modulate = Color(1.0, 1.0, 1.0, clampf(_life / FADE, 0.0, 1.0))


## 造一条带文字的成品消息。
## 【为什么不用描边字】消息落在羊皮纸面板上，底色是可控的 ——
##   深棕字直接印上去最干净；描边留给压在 3D 场景上的文字用。
static func make(text: String) -> HudToast:
	var toast: HudToast = HudToast.new()
	toast.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.add_child(UiTheme.make_label(text, UiTheme.FONT_BODY, UiTheme.TEXT_DARK, 0))
	return toast
