extends Node2D

const SPEED_1_MONTH_SECONDS = 10.0
const PLANETS = [
	{"id": "solara_prime", "name": "Solara Prime"},
	{"id": "vesta", "name": "Vesta"},
	{"id": "kryos", "name": "Kryos"},
]

const INDUSTRY_DEFINITIONS = [
	{
		"id": "ore_mine",
		"name": "Ore Mine",
		"production_rate": 1.0,
		"requirements": {"credits": 25},
		"produces": {"ore": 10},
	},
	{
		"id": "farm",
		"name": "Hydroponic Farm",
		"production_rate": 1.0,
		"requirements": {"credits": 10},
		"produces": {"food": 25},
	},
	{
		"id": "factory",
		"name": "Parts Factory",
		"production_rate": 0.5,
		"requirements": {"credits": 50, "ore": 5},
		"produces": {"parts": 3},
	},
	{
		"id": "rocket_parts",
		"name": "Rocket Parts Factory",
		"production_rate": 0.5,
		"requirements": {"credits": 50, "ore": 5, "parts": 2},
		"produces": {"rocket_parts": 3},
	},
]

@onready var credits_label = $UI/HUD/CreditsLabel
@onready var date_label = $UI/HUD/DateLabel
@onready var IndicatorTime = $UI/HUD/IndicatorTime
@onready var planet_list: ItemList = $"UI/HUD/Planet List"
@onready var industry_button: Button = $UI/HUD/IndustryTest
@onready var industry_popup: PopupPanel = $UI/IndustryBuildPopup
@onready var planet_option: OptionButton = $UI/IndustryBuildPopup/PopupBody/PlanetOption
@onready var industry_option: OptionButton = $UI/IndustryBuildPopup/PopupBody/IndustryOption
@onready var industry_status_label: Label = $UI/IndustryBuildPopup/PopupBody/StatusLabel
@onready var resource_popup: PopupPanel = $UI/Resources
@onready var resource_box: Label = $UI/Resources/VBoxContainer/ResourceBox


func _ready() -> void:
	_setup_planets()
	_setup_industry_types()
	_setup_industry_popup()
	_on_speed_1_button_pressed()
	update_ui()
	update_resoucre_box()


func _get_industry():
	return get_node_or_null("/root/Industry")


func _setup_planets() -> void:
	planet_list.clear()
	for planet in PLANETS:
		planet_list.add_item(str(planet["name"]))

	if planet_list.get_item_count() > 0:
		planet_list.select(0)


func _setup_industry_types() -> void:
	var industry = _get_industry()
	if industry == null:
		return

	for definition in INDUSTRY_DEFINITIONS:
		if industry.has_building_type(str(definition["id"])):
			continue

		industry.register_building_type(
			str(definition["id"]),
			str(definition["name"]),
			float(definition["production_rate"]),
			definition["requirements"] as Dictionary,
			definition["produces"] as Dictionary
		)


func _setup_industry_popup() -> void:
	industry_button.text = "Build Industry"

	planet_option.clear()
	for planet in PLANETS:
		planet_option.add_item(str(planet["name"]))
		planet_option.set_item_metadata(planet_option.get_item_count() - 1, planet["id"])

	industry_option.clear()
	for definition in INDUSTRY_DEFINITIONS:
		industry_option.add_item(str(definition["name"]))
		industry_option.set_item_metadata(industry_option.get_item_count() - 1, definition["id"])

	industry_status_label.text = ""


func update_ui() -> void:
	credits_label.text = "Credits: " + str(GameData.get_value(GameData.CREDITS))
	date_label.text = str(GameData.get_value(GameData.MONTH)) + "/" + str(GameData.get_value(GameData.YEAR))


func _process(delta: float) -> void:
	if not GameData.get_value(GameData.SPEED_1_ACTIVE):
		return

	var month_timer: float = GameData.get_value(GameData.MONTH_TIMER) + delta

	while month_timer >= SPEED_1_MONTH_SECONDS:
		month_timer -= SPEED_1_MONTH_SECONDS
		advance_month()

	GameData.set_value(GameData.MONTH_TIMER, month_timer)


func advance_month() -> void:
	var next_date = DateHelpers.get_next_month(
		GameData.get_value(GameData.MONTH),
		GameData.get_value(GameData.YEAR)
	)
	GameData.set_value(GameData.MONTH, next_date.month)
	GameData.set_value(GameData.YEAR, next_date.year)
	




	update_ui()


func _on_speed_1_button_pressed() -> void:
	GameData.set_value(GameData.SPEED_1_ACTIVE, true)
	IndicatorTime.text = "1x"
	print("1x")


func _on_pause_button_pressed() -> void:
	GameData.set_value(GameData.SPEED_1_ACTIVE, false)
	IndicatorTime.text = "Paused"
	print("Paused")


func _on_industry_test_pressed():
	if industry_popup == null:
		return

	_sync_selected_planet_to_popup()
	industry_status_label.text = ""
	industry_popup.popup_centered(Vector2i(320, 220))


func _on_build_industry_confirmed() -> void:
	var industry = _get_industry()
	if industry == null:
		industry_status_label.text = "Industry backend missing."
		return

	var planet_index = planet_option.selected
	var industry_index = industry_option.selected
	if planet_index < 0 or industry_index < 0:
		industry_status_label.text = "Select a planet and industry."
		return

	var planet_id = str(planet_option.get_item_metadata(planet_index))
	var planet_name = planet_option.get_item_text(planet_index)
	var building_type_id = str(industry_option.get_item_metadata(industry_index))
	var building_name = industry_option.get_item_text(industry_index)
	var building_id = industry.designate_building(
		building_type_id,
		1,
		true,
		{
			"planet_id": planet_id,
			"planet_name": planet_name,
		}
	)

	if building_id.is_empty():
		industry_status_label.text = "Could not build industry."
		return

	industry_status_label.text = "Built " + building_name + " on " + planet_name + "."
	print("Built " + building_name + " on " + planet_name + ": " + building_id)
	_print_industries_by_planet(industry)
	update_ui()


func _on_cancel_industry_build_pressed() -> void:
	industry_popup.hide()


func _sync_selected_planet_to_popup() -> void:
	var selected_items = planet_list.get_selected_items()
	if selected_items.is_empty():
		return

	var selected_planet_index = selected_items[0]
	if selected_planet_index >= 0 and selected_planet_index < planet_option.get_item_count():
		planet_option.select(selected_planet_index)


func _print_industries_by_planet(industry) -> void:
	var buildings = industry.get_buildings()
	if buildings.is_empty():
		return

	print("Industries by planet:")
	for planet in PLANETS:
		var planet_id = str(planet["id"])
		var planet_name = str(planet["name"])
		var built_names = PackedStringArray()
		for building_id in buildings:
			var building = buildings[building_id]
			var metadata = building.get("metadata", {})
			if typeof(metadata) != TYPE_DICTIONARY or str(metadata.get("planet_id", "")) != planet_id:
				continue

			var building_type = industry.get_building_type(str(building.get("type_id", "")))
			built_names.append(str(building_type.get("display_name", building.get("type_id", ""))))

		if not built_names.is_empty():
			print(planet_name + ": " + ", ".join(built_names))


func update_resoucre_box() -> void:
	var industry = get_node_or_null("/root/Industry")
	if industry == null:
		resource_box.text = "{}"
		return
		
	var resources = industry.get_resources()
	var text_lines: Array[String] = []

	for resource_id in resources:
		text_lines.append(str(resource_id).capitalize() + ": " + str(resources[resource_id]))

	resource_box.text = "Resources: \n" + "\n".join(text_lines)



func _on_resource_display_pressed():
	var industry = get_node_or_null("/root/Industry")
	if industry == null:
		return

	var resources = industry.get_resources()
	var text_lines: Array[String] = []

	for resource_id in resources:
		text_lines.append(str(resource_id).capitalize() + ": " + str(resources[resource_id]))

	resource_box.text = "Resources: \n" + "\n".join(text_lines)
	resource_popup.visible = true


func _on_fleet_view_pressed():
	print("Fleetview menu")
	get_tree().change_scene_to_file("res://scenes/ShipView.tscn")
	pass # Replace with function body.


func _on_fuck_your_shit_inator_pressed():
	GameData.reset_save()
	pass # Replace with function body.


func _on_planet_list_item_clicked(index, _at_position, _mouse_button_index):
	var industry = _get_industry()
	print(index)
	var planet = PLANETS[index]
	print(planet)
	var planet_id = str(planet["id"])
	var planet_name = str(planet["name"])
	var buildings = industry.get_buildings()

	print("Industry on " + planet_name + ":")

	var found_any = false
	for building_id in buildings:
		var building = buildings[building_id]
		var metadata = building.get("metadata", {})

		if typeof(metadata) != TYPE_DICTIONARY:
			continue

		if str(metadata.get("planet_id", "")) != planet_id:
			continue

		var building_type = industry.get_building_type(str(building.get("type_id", "")))
		var display_name = str(building_type.get("display_name", building.get("type_id", "")))
		var count = int(building.get("count", 1))
		var active = bool(building.get("active", true))

		print("- " + display_name + " x" + str(count) + " active=" + str(active))
		found_any = true

	if not found_any:
		print("- No industry")

	pass 
