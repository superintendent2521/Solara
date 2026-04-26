extends Node
class_name StorageData

signal value_defined(key: StringName, value: Variant)
signal value_changed(key: StringName, old_value: Variant, new_value: Variant)
signal value_removed(key: StringName, old_value: Variant)

var _values: Dictionary = {}
var _defaults: Dictionary = {}


func define_value(key: StringName, default_value: Variant, overwrite_existing: bool = false) -> void:
	var stored_default = _copy_value(default_value)
	_defaults[key] = stored_default

	if overwrite_existing or not _values.has(key):
		_values[key] = _copy_value(default_value)
		value_defined.emit(key, _copy_value(_values[key]))


func define_values(values: Dictionary, overwrite_existing: bool = false) -> void:
	for key in values:
		define_value(key, values[key], overwrite_existing)


func has_value(key: StringName) -> bool:
	return _values.has(key)


func get_value(key: StringName, fallback: Variant = null) -> Variant:
	if not _values.has(key):
		push_warning("StorageData: requested undefined key '%s'." % key)
		return fallback

	return _copy_value(_values[key])


func set_value(key: StringName, new_value: Variant) -> bool:
	if not _values.has(key):
		push_warning("StorageData: cannot set undefined key '%s'." % key)
		return false

	var old_value = _copy_value(_values[key])
	if old_value == new_value:
		return true

	_values[key] = _copy_value(_coerce_to_default_type(key, new_value))
	value_changed.emit(key, old_value, _copy_value(_values[key]))
	return true


func set_values(values: Dictionary) -> void:
	for key in values:
		set_value(StringName(key), values[key])


func change_value(key: StringName, amount: Variant) -> bool:
	if not _values.has(key):
		push_warning("StorageData: cannot change undefined key '%s'." % key)
		return false

	var current_value = _values[key]
	if not _can_add_values(current_value, amount):
		push_warning("StorageData: key '%s' cannot be changed by '%s'." % [key, amount])
		return false

	return set_value(key, current_value + amount)


func remove_value(key: StringName) -> bool:
	if not _values.has(key):
		return false

	var old_value = _copy_value(_values[key])
	_values.erase(key)
	_defaults.erase(key)
	value_removed.emit(key, old_value)
	return true


func reset_value(key: StringName) -> bool:
	if not _defaults.has(key):
		push_warning("StorageData: cannot reset undefined key '%s'." % key)
		return false

	return set_value(key, _defaults[key])


func reset_all() -> void:
	for key in _defaults:
		set_value(key, _defaults[key])


func get_snapshot() -> Dictionary:
	return _copy_value(_values)


func get_save_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for key in _values:
		snapshot[str(key)] = _copy_value(_values[key])

	return snapshot


func _copy_value(value: Variant) -> Variant:
	var value_type = typeof(value)
	if value_type == TYPE_DICTIONARY or value_type == TYPE_ARRAY:
		return value.duplicate(true)

	return value


func _can_add_values(left: Variant, right: Variant) -> bool:
	var left_type = typeof(left)
	var right_type = typeof(right)
	return (
		(left_type == TYPE_INT or left_type == TYPE_FLOAT)
		and (right_type == TYPE_INT or right_type == TYPE_FLOAT)
	)


func _coerce_to_default_type(key: StringName, value: Variant) -> Variant:
	if not _defaults.has(key):
		return value

	match typeof(_defaults[key]):
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			return float(value)
		TYPE_BOOL:
			return bool(value)
		TYPE_STRING:
			return str(value)
		TYPE_STRING_NAME:
			return StringName(value)
		_:
			return value
