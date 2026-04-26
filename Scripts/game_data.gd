extends "res://Scripts/storage_data.gd"

const SAVE_PATH = "user://save_data.json"
const SAVE_INTERVAL_SECONDS = 1.0

const CREDITS: StringName = &"credits"
const MONTH: StringName = &"month"
const YEAR: StringName = &"year"
const SPEED_1_ACTIVE: StringName = &"speed_1_active"
const MONTH_TIMER: StringName = &"month_timer"
const RESOURCES: StringName = &"resources"
const INDUSTRY_BUILDINGS: StringName = &"industry_buildings"
const INDUSTRY_NEXT_BUILDING_ID: StringName = &"industry_next_building_id"

var _save_dirty = false
var _save_timer = 0.0


func _ready() -> void:
	define_values({
		CREDITS: 2300,
		MONTH: 1,
		YEAR: 2030,
		SPEED_1_ACTIVE: false,
		MONTH_TIMER: 0.0,
		RESOURCES: {},
		INDUSTRY_BUILDINGS: {},
		INDUSTRY_NEXT_BUILDING_ID: 1,
	})

	load_data()
	value_changed.connect(_on_value_changed)


func _process(delta: float) -> void:
	if not _save_dirty:
		return

	_save_timer += delta
	if _save_timer >= SAVE_INTERVAL_SECONDS:
		save_data()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		save_data()


func save_data() -> bool:
	var save_file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if save_file == null:
		push_warning("GameData: could not open save file '%s'." % SAVE_PATH)
		return false

	save_file.store_string(JSON.stringify(get_save_snapshot(), "\t"))
	save_file.flush()
	_save_dirty = false
	_save_timer = 0.0
	return true


func load_data() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var save_file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if save_file == null:
		push_warning("GameData: could not read save file '%s'." % SAVE_PATH)
		return false

	var parsed_data = JSON.parse_string(save_file.get_as_text())
	if typeof(parsed_data) != TYPE_DICTIONARY:
		push_warning("GameData: save file '%s' is not valid save data." % SAVE_PATH)
		return false

	set_values(parsed_data)
	_save_dirty = false
	_save_timer = 0.0
	return true


func reset_save() -> void:
	reset_all()
	save_data()


func _on_value_changed(_key: StringName, _old_value: Variant, _new_value: Variant) -> void:
	_save_dirty = true
