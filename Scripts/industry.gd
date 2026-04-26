extends Node

signal building_type_registered(building_type_id: String)
signal building_designated(building_id: String, building_type_id: String)
signal building_removed(building_id: String, building_type_id: String)
signal production_processed(report: Dictionary)
signal resource_changed(resource_id: String, old_amount: float, new_amount: float)

const DEFAULT_BUILDING_COUNT = 1

var _building_types: Dictionary = {}


func register_building_type(
	building_type_id: String,
	display_name: String,
	production_rate: float,
	requirements: Dictionary,
	produces: Dictionary
) -> bool:
	if building_type_id.is_empty():
		push_warning("Industry: building type id cannot be empty.")
		return false

	if production_rate < 0.0:
		push_warning("Industry: production rate for '%s' cannot be negative." % building_type_id)
		return false

	var normalized_requirements = _normalize_resource_map(requirements)
	var normalized_produces = _normalize_resource_map(produces)
	if normalized_produces.is_empty():
		push_warning("Industry: building type '%s' must produce at least one resource." % building_type_id)
		return false

	_building_types[building_type_id] = {
		"id": building_type_id,
		"display_name": display_name,
		"production_rate": production_rate,
		"requirements": normalized_requirements,
		"produces": normalized_produces,
	}
	building_type_registered.emit(building_type_id)
	return true


func has_building_type(building_type_id: String) -> bool:
	return _building_types.has(building_type_id)


func get_building_type(building_type_id: String) -> Dictionary:
	if not _building_types.has(building_type_id):
		return {}

	return _building_types[building_type_id].duplicate(true)


func get_building_types() -> Dictionary:
	return _building_types.duplicate(true)


func designate_building(
	building_type_id: String,
	count: int = DEFAULT_BUILDING_COUNT,
	active: bool = true,
	metadata: Dictionary = {}
) -> String:
	if not _building_types.has(building_type_id):
		push_warning("Industry: cannot designate unknown building type '%s'." % building_type_id)
		return ""

	if count <= 0:
		push_warning("Industry: building count must be greater than zero.")
		return ""

	var building_id = _get_next_building_id()
	var buildings = _get_buildings()
	buildings[building_id] = {
		"id": building_id,
		"type_id": building_type_id,
		"count": count,
		"active": active,
		"metadata": metadata.duplicate(true),
	}
	GameData.set_value(GameData.INDUSTRY_BUILDINGS, buildings)

	building_designated.emit(building_id, building_type_id)
	return building_id


func remove_building(building_id: String) -> bool:
	var buildings = _get_buildings()
	if not buildings.has(building_id):
		return false

	var building_type_id = str(buildings[building_id].get("type_id", ""))
	buildings.erase(building_id)
	GameData.set_value(GameData.INDUSTRY_BUILDINGS, buildings)
	building_removed.emit(building_id, building_type_id)
	return true


func set_building_active(building_id: String, active: bool) -> bool:
	return update_building(building_id, {"active": active})


func set_building_count(building_id: String, count: int) -> bool:
	if count <= 0:
		push_warning("Industry: building count must be greater than zero.")
		return false

	return update_building(building_id, {"count": count})


func update_building(building_id: String, values: Dictionary) -> bool:
	var buildings = _get_buildings()
	if not buildings.has(building_id):
		return false

	var building = _normalize_building(building_id, buildings[building_id])
	for key in values:
		if key == "id" or key == "type_id":
			continue

		if key == "count" and int(values[key]) <= 0:
			push_warning("Industry: building count must be greater than zero.")
			return false

		building[key] = values[key]

	buildings[building_id] = building
	GameData.set_value(GameData.INDUSTRY_BUILDINGS, buildings)
	return true


func get_building(building_id: String) -> Dictionary:
	var buildings = _get_buildings()
	if not buildings.has(building_id):
		return {}

	return _normalize_building(building_id, buildings[building_id])


func get_buildings() -> Dictionary:
	var normalized_buildings: Dictionary = {}
	var buildings = _get_buildings()
	for building_id in buildings:
		normalized_buildings[building_id] = _normalize_building(building_id, buildings[building_id])

	return normalized_buildings


func get_resource(resource_id: String) -> float:
	if resource_id == str(GameData.CREDITS):
		return float(GameData.get_value(GameData.CREDITS, 0))

	var resources = _get_resources()
	return float(resources.get(resource_id, 0.0))


func set_resource(resource_id: String, amount: float) -> bool:
	if amount < 0.0:
		push_warning("Industry: resource '%s' cannot be set below zero." % resource_id)
		return false

	return _set_resource_amount(resource_id, amount)


func add_resource(resource_id: String, amount: float) -> bool:
	var next_amount = get_resource(resource_id) + amount
	if next_amount < 0.0:
		return false

	return _set_resource_amount(resource_id, next_amount)


func can_run_building(building_id: String) -> bool:
	var building = get_building(building_id)
	if building.is_empty() or not bool(building.get("active", true)):
		return false

	var building_type = get_building_type(str(building.get("type_id", "")))
	if building_type.is_empty():
		return false

	var multiplier = _get_building_multiplier(building, building_type)
	var requirements = building_type.get("requirements", {})
	for resource_id in requirements:
		if get_resource(resource_id) < float(requirements[resource_id]) * multiplier:
			return false

	return true


func process_month() -> Dictionary:
	var report = {
		"consumed": {},
		"produced": {},
		"blocked": {},
		"processed_buildings": [],
	}

	var buildings = get_buildings()
	for building_id in buildings:
		var building = buildings[building_id]
		if not bool(building.get("active", true)):
			continue

		var building_type = get_building_type(str(building.get("type_id", "")))
		if building_type.is_empty():
			report["blocked"][building_id] = "unknown_building_type"
			continue

		var multiplier = _get_building_multiplier(building, building_type)
		if not _has_requirements(building_type.get("requirements", {}), multiplier):
			report["blocked"][building_id] = "missing_requirements"
			continue

		_apply_resource_delta(building_type.get("requirements", {}), -multiplier, report["consumed"])
		_apply_resource_delta(building_type.get("produces", {}), multiplier, report["produced"])
		report["processed_buildings"].append(building_id)

	production_processed.emit(report.duplicate(true))
	return report


func _get_next_building_id() -> String:
	var next_id = int(GameData.get_value(GameData.INDUSTRY_NEXT_BUILDING_ID, 1))
	GameData.set_value(GameData.INDUSTRY_NEXT_BUILDING_ID, next_id + 1)
	return "building_%s" % next_id


func _get_resources() -> Dictionary:
	return GameData.get_value(GameData.RESOURCES, {})


func _get_buildings() -> Dictionary:
	return GameData.get_value(GameData.INDUSTRY_BUILDINGS, {})


func _normalize_resource_map(resources: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for resource_id in resources:
		var amount = float(resources[resource_id])
		if amount <= 0.0:
			continue

		normalized[str(resource_id)] = amount

	return normalized


func _normalize_building(building_id: String, building: Dictionary) -> Dictionary:
	var metadata = building.get("metadata", {})
	if typeof(metadata) != TYPE_DICTIONARY:
		metadata = {}

	return {
		"id": str(building.get("id", building_id)),
		"type_id": str(building.get("type_id", "")),
		"count": max(1, int(building.get("count", DEFAULT_BUILDING_COUNT))),
		"active": bool(building.get("active", true)),
		"metadata": metadata.duplicate(true),
	}


func _get_building_multiplier(building: Dictionary, building_type: Dictionary) -> float:
	return float(building.get("count", DEFAULT_BUILDING_COUNT)) * float(building_type.get("production_rate", 1.0))


func _has_requirements(requirements: Dictionary, multiplier: float) -> bool:
	for resource_id in requirements:
		if get_resource(resource_id) < float(requirements[resource_id]) * multiplier:
			return false

	return true


func _apply_resource_delta(resource_amounts: Dictionary, multiplier: float, report_bucket: Dictionary) -> void:
	for resource_id in resource_amounts:
		var amount = float(resource_amounts[resource_id]) * multiplier
		add_resource(resource_id, amount)
		report_bucket[resource_id] = float(report_bucket.get(resource_id, 0.0)) + abs(amount)


func _set_resource_amount(resource_id: String, amount: float) -> bool:
	var old_amount = get_resource(resource_id)

	if resource_id == str(GameData.CREDITS):
		var did_set_credits = GameData.set_value(GameData.CREDITS, amount)
		if did_set_credits:
			resource_changed.emit(resource_id, old_amount, amount)
		return did_set_credits

	var resources = _get_resources()
	resources[resource_id] = amount
	var did_set = GameData.set_value(GameData.RESOURCES, resources)
	if did_set:
		resource_changed.emit(resource_id, old_amount, amount)

	return did_set

func get_resources() -> Dictionary:
	return _get_resources()
