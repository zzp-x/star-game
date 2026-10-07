extends Node
## 存档读写：JSON 格式 + version 字段 + 逐级迁移链。
##
## 【层级】L3 单例（Autoload）
## 【为什么不用 ResourceSaver / ResourceLoader】
##   · 存档存的是「玩家数据」，不是「引擎资源」。用 Resource 存会让玩家能直接改数值；
##   · L2 的类一旦改名或改字段，旧档会整档报废 —— JSON + version 可以逐级迁移；
##   · JSON 可读，出问题时能直接打开看（见 DESIGN.md §3.9）。
##
## 【版本历史】
##   v1  2D 初版
##   v2  改用 GDScript
##   v3  农场格位键统一为 "x,y"
##   v4  ★ 3D 化：玩家位置 Vector2 → Vector3 + rotation_y（M2 实装）
##
## ⚠️ 不要给本文件加 `class_name` —— 与 Autoload 单例名冲突。

const SAVE_DIR: String = "user://saves"
const CURRENT_VERSION: int = 4
const MAX_SLOTS: int = 3


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


# ── 存 ───────────────────────────────────────────────────

func save_game(slot: int = 1) -> bool:
	if slot < 1 or slot > MAX_SLOTS:
		push_error("SaveManager: 非法存档槽 %d" % slot)
		return false

	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

	var payload: Dictionary = {
		"version": CURRENT_VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"engine": Engine.get_version_info().get("string", "unknown"),
		"time": TimeManager.to_dict(),
		"game": GameManager.to_dict(),
	}

	var path: String = slot_path(slot)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: 无法写入 %s（%s）" % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

	EventBus.game_saved.emit(slot)
	print("[存档] 已保存到槽 %d → %s" % [slot, path])
	return true


# ── 读 ───────────────────────────────────────────────────

func load_game(slot: int = 1) -> bool:
	var path: String = slot_path(slot)
	if not FileAccess.file_exists(path):
		push_warning("SaveManager: 槽 %d 没有存档" % slot)
		return false

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: 无法读取 %s" % path)
		return false
	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("SaveManager: 存档 %s 不是合法 JSON 对象" % path)
		return false

	var payload: Dictionary = _migrate(VariantUtil.to_dict(parsed))
	TimeManager.from_dict(VariantUtil.dict_dict(payload, "time"))
	GameManager.from_dict(VariantUtil.dict_dict(payload, "game"))

	EventBus.game_loaded.emit(slot)
	print("[存档] 已读取槽 %d（存档版本 %d → 当前 %d）" % [
		slot, VariantUtil.dict_int(payload, "version", 0), CURRENT_VERSION,
	])
	return true


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func delete_save(slot: int) -> bool:
	var path: String = slot_path(slot)
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK


## 列出所有槽的概要，供存档选择界面使用（M2）。
func list_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot: int in range(1, MAX_SLOTS + 1):
		var exists: bool = has_save(slot)
		var info: Dictionary = {"slot": slot, "exists": exists, "saved_at": "", "version": 0}
		if exists:
			var file: FileAccess = FileAccess.open(slot_path(slot), FileAccess.READ)
			if file != null:
				var parsed: Variant = JSON.parse_string(file.get_as_text())
				file.close()
				if parsed is Dictionary:
					var data: Dictionary = VariantUtil.to_dict(parsed)
					info["saved_at"] = VariantUtil.dict_str(data, "saved_at", "")
					info["version"] = VariantUtil.dict_int(data, "version", 0)
		out.append(info)
	return out


func slot_path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]


# ── 迁移链 ───────────────────────────────────────────────

## 逐级把旧档升到 CURRENT_VERSION。
## 【纪律】每个 if 只负责「从 N 升到 N+1」的一小步，不要跳过中间版本。
func _migrate(payload: Dictionary) -> Dictionary:
	var version: int = VariantUtil.dict_int(payload, "version", 1)

	if version < 2:
		# v1 → v2：C# 时期字段名大写驼峰 → snake_case（字段名逐一改名）
		version = 2

	if version < 3:
		# v2 → v3：农场格位键统一为 "x,y"
		version = 3

	if version < 4:
		# v3 → v4：3D 化。玩家位置 Vector2 → Vector3 + rotation_y。
		# M0 尚未写入玩家位置，这里只占位并预留升级入口。
		var game: Dictionary = VariantUtil.dict_dict(payload, "game")
		if game.has("player_position"):
			var old_pos: Dictionary = VariantUtil.to_dict(game["player_position"])
			game["player_position"] = {
				"x": VariantUtil.dict_float(old_pos, "x", 0.0),
				"y": 0.0,
				"z": VariantUtil.dict_float(old_pos, "y", 0.0),
			}
			payload["game"] = game
		version = 4

	payload["version"] = CURRENT_VERSION
	return payload
