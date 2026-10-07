class_name VariantUtil
extends RefCounted
## Variant → 具体类型的转换**集中地**。
##
## 【为什么单独开一个文件】
## project.godot 把 `unsafe_*` 系列警告设成了 **Error**（见 DESIGN.md §4.7）。
## 而"从一个 JSON 解析出来的 Variant 字典里读数据"天生就是不安全的 ——
## 与其在整个项目里到处撒 `@warning_ignore`，不如把这类转换**全部隔离在这一个文件**，
## 其余代码保持 100% 严格。审代码时只需要盯这一个文件。
##
## 【实现要点 · 值得学】全部用 `if value is 目标类型: return value` 的**类型收窄**写法，
##   而不是 `int(variant)` 或 `variant as int`。
##   因为：
##     · `if value is int or value is float:` ⇒ **不会**收窄（`or` 破坏收窄），仍报 unsafe
##     · 拆成两个独立的 `if value is int:` / `if value is float:` ⇒ 收窄生效，零警告
##   这条区分很反直觉，但它是这套严格模式能不能用得舒服的关键。
##
## 【纪律】除本文件外，任何地方都不应出现 Variant → 具体类型的裸转换。

static func to_int(value: Variant, fallback: int = 0) -> int:
	if value is int:
		return value
	if value is float:
		@warning_ignore("unsafe_call_argument")
		var converted: int = int(value)
		return converted
	if value is bool:
		return 1 if value else 0
	return fallback


static func to_float(value: Variant, fallback: float = 0.0) -> float:
	if value is float:
		return value
	if value is int:
		@warning_ignore("unsafe_call_argument")
		var converted: float = float(value)
		return converted
	return fallback


static func to_bool(value: Variant, fallback: bool = false) -> bool:
	if value is bool:
		return value
	if value is int:
		return value != 0
	if value is float:
		return value != 0.0
	return fallback


static func to_str(value: Variant, fallback: String = "") -> String:
	if value is String:
		return value
	if value is StringName:
		@warning_ignore("unsafe_call_argument")
		var converted: String = String(value)
		return converted
	return fallback


static func to_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value
	return {}


static func to_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


static func to_string_array(value: Variant) -> PackedStringArray:
	if value is PackedStringArray:
		return value
	var out: PackedStringArray = PackedStringArray()
	if value is Array:
		for item: Variant in value:
			out.append(to_str(item))
	return out


static func to_crop_data(value: Variant) -> CropData:
	if value is CropData:
		return value
	return null


static func to_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	return Vector3.ZERO


static func to_vector2i(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	return Vector2i.ZERO


# ── 从字典里安全取值 ─────────────────────────────────────

static func dict_int(data: Dictionary, key: String, fallback: int = 0) -> int:
	return to_int(data.get(key), fallback)


static func dict_float(data: Dictionary, key: String, fallback: float = 0.0) -> float:
	return to_float(data.get(key), fallback)


static func dict_bool(data: Dictionary, key: String, fallback: bool = false) -> bool:
	return to_bool(data.get(key), fallback)


static func dict_str(data: Dictionary, key: String, fallback: String = "") -> String:
	return to_str(data.get(key), fallback)


static func dict_dict(data: Dictionary, key: String) -> Dictionary:
	return to_dict(data.get(key))
