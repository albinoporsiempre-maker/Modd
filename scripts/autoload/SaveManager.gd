extends Node






const SAVE_VERSION: = 1
const SAVE_DIR: = "user://saves"

const MAX_SAVES: = 20


var playtime: float = 0.0
var _counting: bool = true

func _process(delta: float) -> void :
	if _counting:
		playtime += delta

func set_counting(v: bool) -> void :
	_counting = v

func reset_playtime() -> void :
	playtime = 0.0

func _ensure_dir() -> void :
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SAVE_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))



func write_snapshot(snapshot: Dictionary) -> String:
	_ensure_dir()
	var unix: = int(Time.get_unix_time_from_system())


	var fname: = "%s/save_%d_%03d.json" % [SAVE_DIR, unix, Time.get_ticks_msec() % 1000]
	var f: = FileAccess.open(fname, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write %s" % fname)
		return ""
	f.store_string(JSON.stringify(snapshot, "  "))
	f.close()
	_prune_old()
	return fname



func _prune_old() -> void :
	var saves: = list_saves()
	for i in range(MAX_SAVES, saves.size()):
		delete_save(saves[i]["path"])


func read_snapshot(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f: = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var txt: = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: malformed save '%s' (skipped)" % path)
		return {}
	if int(parsed.get("save_version", 0)) != SAVE_VERSION:
		push_warning("SaveManager: unknown save_version in '%s' (skipped)" % path)
		return {}
	return parsed


func list_saves() -> Array:
	var out: Array = []
	var dir_abs: = ProjectSettings.globalize_path(SAVE_DIR)
	if not DirAccess.dir_exists_absolute(dir_abs):
		return out
	var d: = DirAccess.open(SAVE_DIR)
	if d == null:
		return out
	for fn in d.get_files():
		if not fn.ends_with(".json"):
			continue
		var path: = "%s/%s" % [SAVE_DIR, fn]
		var data: = read_snapshot(path)
		if data.is_empty():
			continue
		out.append({
			"path": path, 
			"timestamp_unix": int(data.get("timestamp_unix", 0)), 
			"timestamp_str": str(data.get("timestamp_str", "")), 
			"playtime_seconds": float(data.get("playtime_seconds", 0.0)), 
			"data": data, 
		})


	out.sort_custom( func(a, b):
		if a["timestamp_unix"] != b["timestamp_unix"]:
			return a["timestamp_unix"] > b["timestamp_unix"]
		return a["path"] > b["path"])
	return out

func delete_save(path: String) -> void :
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func format_playtime(seconds: float) -> String:
	var s: = int(seconds)
	return "%02d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]



static func format_datetime(t: Dictionary) -> String:
	var months: = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
	return "%02d %s %d — %02d:%02d" % [int(t.get("day", 1)), months[clampi(int(t.get("month", 1)) - 1, 0, 11)], int(t.get("year", 2000)), int(t.get("hour", 0)), int(t.get("minute", 0))]
