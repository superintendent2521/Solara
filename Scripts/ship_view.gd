extends Node2D

const SPEED_1_MONTH_SECONDS = 10.0

@onready var credits_label: Label = $UI/HUD/CreditsLabel
@onready var date_label: Label = $UI/HUD/DateLabel
@onready var indicator_time: Label = $UI/HUD/IndicatorTime


func _ready() -> void:
	update_ui()


func _process(delta: float) -> void:
	if not GameData.get_value(GameData.SPEED_1_ACTIVE):
		return

	var month_timer: float = GameData.get_value(GameData.MONTH_TIMER) + delta

	while month_timer >= SPEED_1_MONTH_SECONDS:
		month_timer -= SPEED_1_MONTH_SECONDS
		advance_month()

	GameData.set_value(GameData.MONTH_TIMER, month_timer)


func update_ui() -> void:
	credits_label.text = "Credits: " + str(GameData.get_value(GameData.CREDITS))
	date_label.text = str(GameData.get_value(GameData.MONTH)) + "/" + str(GameData.get_value(GameData.YEAR))

	if GameData.get_value(GameData.SPEED_1_ACTIVE):
		indicator_time.text = "1x"
	else:
		indicator_time.text = "Paused"


func advance_month() -> void:
	var next_date = DateHelpers.get_next_month(
		GameData.get_value(GameData.MONTH),
		GameData.get_value(GameData.YEAR)
	)
	GameData.set_value(GameData.MONTH, next_date.month)
	GameData.set_value(GameData.YEAR, next_date.year)

	var industry = get_node_or_null("/root/Industry")
	if industry != null:
		industry.process_month()

	update_ui()


func _on_speed_1_button_pressed() -> void:
	GameData.set_value(GameData.SPEED_1_ACTIVE, true)
	update_ui()
	print("1x")


func _on_pause_button_pressed() -> void:
	GameData.set_value(GameData.SPEED_1_ACTIVE, false)
	update_ui()
	print("Paused")


func _on_button_pressed():
	print("Main")
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	
	pass # Replace with function body.
