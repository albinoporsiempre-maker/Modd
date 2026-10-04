extends Node








signal changed

const SAVE_PATH: = "user://meta_save.json"

var flags: Dictionary = {}

func _ready() -> void :
	load_save()

func set_flag(name: String, value: Variant = true) -> void :
	if flags.get(name) == value:
		return
	flags[name] = value
	save()
	changed.emit()

func has_flag(name: String) -> bool:
	return flags.has(name) and flags[name] != false

func save() -> void :
	var f: = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("MetaState: cannot write %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(flags, "  "))
	f.close()

func load_save() -> void :
	flags.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f: = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		flags = parsed


func clear_all() -> void :
	flags.clear()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	save()
	changed.emit()
