class_name EconomyState
extends RefCounted

const RESOURCE_IDS: Array[String] = ["energy", "food", "minerals", "goods", "research"]
const MONTH_NAMES: Array[String] = [
	"January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December"
]

var month: int = 0
var start_year: int = 2200
var credits: float = 850.0
var regions: Array[Dictionary] = []
var building_definitions: Dictionary = {}
var technologies: Dictionary = {
	"industrial_methods": {
		"name": "Industrial Methods",
		"cost": 60.0,
		"description": "+15% building output; unlocks Research Campuses.",
	},
	"orbital_logistics": {
		"name": "Orbital Logistics",
		"cost": 150.0,
		"description": "Unlocks a trade route and +10% building output.",
	},
}
var unlocked_technologies: Array[String] = []
var trade_route_active: bool = false
var rival: Dictionary = {
	"name": "Helix Combine",
	"population": 920.0,
	"industrial_capacity": 8.0,
	"influence": 12.0,
}
var last_report: Dictionary = {}
var alerts: Array[String] = []
var event_log: Array[String] = []
var game_over: bool = false
var victory: bool = false
var end_reason: String = ""
var _low_stability_months: int = 0
var _starvation_months: int = 0


func _init(definitions: Dictionary = {}) -> void:
	building_definitions = definitions.duplicate(true)
	regions = [
		_make_region("aurora", "Aurora Basin", 1120.0, 76.0,
			{"energy": 95.0, "food": 105.0, "minerals": 70.0, "goods": 26.0, "research": 0.0},
			{"hydroponics_farm": 2, "deep_core_mine": 1, "fabrication_plant": 1, "fusion_array": 1, "research_campus": 0}, 1.15, 1.0),
		_make_region("cinder", "Cinder Reach", 740.0, 68.0,
			{"energy": 55.0, "food": 58.0, "minerals": 115.0, "goods": 14.0, "research": 0.0},
			{"hydroponics_farm": 1, "deep_core_mine": 2, "fabrication_plant": 0, "fusion_array": 1, "research_campus": 0}, 0.8, 1.35),
		_make_region("pelagos", "Pelagos Arc", 610.0, 72.0,
			{"energy": 70.0, "food": 92.0, "minerals": 45.0, "goods": 18.0, "research": 0.0},
			{"hydroponics_farm": 2, "deep_core_mine": 0, "fabrication_plant": 0, "fusion_array": 1, "research_campus": 0}, 1.3, 0.7),
	]
	event_log.append("Mandate established. Grow Solara without breaking its supply lines.")


func _make_region(
	id: String, display_name: String, population: float, happiness: float,
	stockpiles: Dictionary, buildings: Dictionary, food_modifier: float, mineral_modifier: float
) -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"population": population,
		"happiness": happiness,
		"stockpiles": stockpiles,
		"buildings": buildings,
		"food_modifier": food_modifier,
		"mineral_modifier": mineral_modifier,
	}


func simulate_month() -> void:
	if game_over:
		return
	month += 1
	alerts.clear()
	last_report = {}
	var empire_food_ratio := 1.0
	for region in regions:
		var result := _simulate_region(region)
		last_report[region.id] = result.report
		empire_food_ratio = min(empire_food_ratio, result.food_ratio)
	_apply_research_unlocks()
	_simulate_rival()
	_apply_end_conditions(empire_food_ratio)
	if not game_over and month >= 50:
		game_over = true
		victory = industrial_capacity() >= 42.0 or total_population() >= 3600.0
		end_reason = "Fifty-month mandate complete: " + ("Solara is self-sustaining." if victory else "the colony missed its growth targets.")


func _simulate_region(region: Dictionary) -> Dictionary:
	var stock: Dictionary = region.stockpiles
	var report := _new_flow_report(stock)
	var available_workers := region.population * 0.46
	var requested_workers := 0.0
	for building_id in region.buildings:
		if building_definitions.has(building_id):
			requested_workers += float(building_definitions[building_id].get("workers", 0)) * int(region.buildings[building_id])
	var staffing := min(1.0, available_workers / max(1.0, requested_workers))

	# Power producers run first so the other industries can use this month's energy.
	var ordered_ids: Array[String] = ["fusion_array"]
	for building_id in region.buildings:
		if building_id != "fusion_array":
			ordered_ids.append(building_id)
	for building_id in ordered_ids:
		_process_building(region, building_id, staffing, report)

	var food_needed := region.population * 0.018
	var goods_needed := region.population * 0.004
	var food_ratio := _consume_population(stock, "food", food_needed, report)
	var goods_ratio := _consume_population(stock, "goods", goods_needed, report)
	if food_ratio < 0.999:
		region.happiness -= (1.0 - food_ratio) * 14.0
		alerts.append("%s: food rationing (%d%% supplied)." % [region.name, round(food_ratio * 100.0)])
	else:
		region.happiness += 0.35
	if goods_ratio < 0.999:
		region.happiness -= (1.0 - goods_ratio) * 7.0
		alerts.append("%s: consumer goods shortage." % region.name)
	else:
		region.happiness += 0.18
	if staffing < 0.999:
		alerts.append("%s: industry is only %d%% staffed." % [region.name, round(staffing * 100.0)])

	var tax_income := region.population * 0.021 * (0.65 + region.happiness / 200.0)
	credits += tax_income
	report.credits["taxes"] = tax_income
	var growth_rate := 0.0035 * clamp((region.happiness - 35.0) / 45.0, -0.7, 1.0)
	if food_ratio < 0.5:
		growth_rate -= 0.012
	region.population = max(50.0, region.population * (1.0 + growth_rate))
	region.happiness = clamp(region.happiness, 0.0, 100.0)
	for resource_id in RESOURCE_IDS:
		report[resource_id].ending = float(stock.get(resource_id, 0.0))
	return {"report": report, "food_ratio": food_ratio}


func _process_building(region: Dictionary, building_id: String, staffing: float, report: Dictionary) -> void:
	var count := int(region.buildings.get(building_id, 0))
	if count <= 0 or not building_definitions.has(building_id):
		return
	var definition: Dictionary = building_definitions[building_id]
	var unlock_id := str(definition.get("unlock", ""))
	if not unlock_id.is_empty() and not unlocked_technologies.has(unlock_id):
		return
	var scale := float(count) * staffing
	for resource_id in definition.get("monthly_input", {}):
		var required := float(definition.monthly_input[resource_id]) * scale
		if float(region.stockpiles.get(resource_id, 0.0)) < required:
			alerts.append("%s: %s halted (needs %s)." % [region.name, definition.name, resource_id.capitalize()])
			return
	for resource_id in definition.get("monthly_input", {}):
		var used := float(definition.monthly_input[resource_id]) * scale
		region.stockpiles[resource_id] = float(region.stockpiles.get(resource_id, 0.0)) - used
		report[resource_id].industry -= used
	var output_modifier := 1.0
	if unlocked_technologies.has("industrial_methods"):
		output_modifier += 0.15
	if unlocked_technologies.has("orbital_logistics"):
		output_modifier += 0.10
	for resource_id in definition.get("monthly_output", {}):
		var modifier := output_modifier
		if resource_id == "food":
			modifier *= float(region.food_modifier)
		elif resource_id == "minerals":
			modifier *= float(region.mineral_modifier)
		var produced := float(definition.monthly_output[resource_id]) * scale * modifier
		region.stockpiles[resource_id] = float(region.stockpiles.get(resource_id, 0.0)) + produced
		report[resource_id].production += produced
	var maintenance := float(definition.get("maintenance", 0.0)) * scale
	credits -= maintenance
	report.credits["maintenance"] = float(report.credits.maintenance) - maintenance


func _consume_population(stock: Dictionary, resource_id: String, needed: float, report: Dictionary) -> float:
	var available := float(stock.get(resource_id, 0.0))
	var consumed := min(available, needed)
	stock[resource_id] = available - consumed
	report[resource_id].population -= consumed
	return consumed / max(0.001, needed)


func _new_flow_report(stock: Dictionary) -> Dictionary:
	var report := {"credits": {"taxes": 0.0, "maintenance": 0.0}}
	for resource_id in RESOURCE_IDS:
		report[resource_id] = {
			"starting": float(stock.get(resource_id, 0.0)),
			"production": 0.0,
			"imports": 0.0,
			"industry": 0.0,
			"population": 0.0,
			"ending": 0.0,
		}
	if trade_route_active:
		var import_region: Dictionary = regions[1]
		import_region.stockpiles.minerals = float(import_region.stockpiles.minerals) + 12.0
		report.minerals.imports += 12.0
		credits -= 7.0
		report.credits.maintenance -= 7.0
	return report


func construct_building(region_index: int, building_id: String) -> Dictionary:
	if game_over:
		return {"ok": false, "message": "The mandate has ended."}
	if region_index < 0 or region_index >= regions.size() or not building_definitions.has(building_id):
		return {"ok": false, "message": "Invalid construction order."}
	var definition: Dictionary = building_definitions[building_id]
	var unlock_id := str(definition.get("unlock", ""))
	if not unlock_id.is_empty() and not unlocked_technologies.has(unlock_id):
		return {"ok": false, "message": "%s requires %s." % [definition.name, technologies[unlock_id].name]}
	var region: Dictionary = regions[region_index]
	var cost: Dictionary = definition.get("construction_cost", {})
	var credit_cost := float(cost.get("credits", 0.0))
	var mineral_cost := float(cost.get("minerals", 0.0))
	if credits < credit_cost:
		return {"ok": false, "message": "Treasury needs %d more credits." % ceil(credit_cost - credits)}
	if float(region.stockpiles.minerals) < mineral_cost:
		return {"ok": false, "message": "%s needs %d more minerals." % [region.name, ceil(mineral_cost - float(region.stockpiles.minerals))]}
	credits -= credit_cost
	region.stockpiles.minerals = float(region.stockpiles.minerals) - mineral_cost
	region.buildings[building_id] = int(region.buildings.get(building_id, 0)) + 1
	var message := "Built %s in %s." % [definition.name, region.name]
	event_log.push_front(message)
	return {"ok": true, "message": message}


func establish_trade_route() -> Dictionary:
	if trade_route_active:
		return {"ok": false, "message": "The Cinder mineral route is already active."}
	if not unlocked_technologies.has("orbital_logistics"):
		return {"ok": false, "message": "Research Orbital Logistics first."}
	if credits < 300.0:
		return {"ok": false, "message": "Establishing the route costs 300 credits."}
	credits -= 300.0
	trade_route_active = true
	event_log.push_front("Trade route established: Cinder Reach imports +12 minerals/month.")
	return {"ok": true, "message": event_log[0]}


func _apply_research_unlocks() -> void:
	var total := total_resource("research")
	for technology_id in ["industrial_methods", "orbital_logistics"]:
		if not unlocked_technologies.has(technology_id) and total >= float(technologies[technology_id].cost):
			unlocked_technologies.append(technology_id)
			var message := "Technology unlocked: %s." % technologies[technology_id].name
			event_log.push_front(message)
			alerts.append(message)


func _simulate_rival() -> void:
	rival.population *= 1.0045
	rival.industrial_capacity += 0.42 + float(rival.population) / 9000.0
	rival.influence += 0.16
	if int(month) % 12 == 0:
		event_log.push_front("Helix Combine expands its orbital industrial network.")


func _apply_end_conditions(food_ratio: float) -> void:
	if credits < -250.0:
		game_over = true
		end_reason = "Bankruptcy: the treasury fell below -250 credits."
		return
	_starvation_months = _starvation_months + 1 if food_ratio < 0.35 else 0
	_low_stability_months = _low_stability_months + 1 if average_happiness() < 20.0 else 0
	if _starvation_months >= 3:
		game_over = true
		end_reason = "Colony failure: severe starvation persisted for three months."
	elif _low_stability_months >= 3:
		game_over = true
		end_reason = "Colony failure: instability persisted for three months."
	elif total_population() >= 3600.0 or industrial_capacity() >= 50.0:
		game_over = true
		victory = true
		end_reason = "Victory: Solara has become a self-sustaining industrial power."


func total_resource(resource_id: String) -> float:
	var total := 0.0
	for region in regions:
		total += float(region.stockpiles.get(resource_id, 0.0))
	return total


func total_population() -> float:
	var total := 0.0
	for region in regions:
		total += float(region.population)
	return total


func average_happiness() -> float:
	var weighted := 0.0
	for region in regions:
		weighted += float(region.happiness) * float(region.population)
	return weighted / max(1.0, total_population())


func industrial_capacity() -> float:
	var score := 0.0
	for region in regions:
		for building_id in region.buildings:
			score += int(region.buildings[building_id]) * (2.0 if building_id == "fabrication_plant" else 1.0)
	return score


func current_date() -> String:
	return "%s %d" % [MONTH_NAMES[month % 12], start_year + month / 12]


func get_region(index: int) -> Dictionary:
	return regions[clamp(index, 0, regions.size() - 1)]

