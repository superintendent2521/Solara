# Industry System

The industry backend lives in `res://Scripts/industry.gd` and is registered as the `Industry` autoload in `project.godot`.

It handles:

- Building type definitions
- Designated production buildings
- Resource storage
- Monthly production processing
- Signals for backend/UI integration

## Core Concepts

### Building Types

A building type defines what a kind of building does.

Each building type has:

- `id`: stable string ID used by code and saved buildings
- `display_name`: player-facing name
- `production_rate`: multiplier applied every production tick
- `requirements`: resources consumed per production-rate unit
- `produces`: resources created per production-rate unit

Example:

```gdscript
Industry.register_building_type(
	"ore_mine",
	"Ore Mine",
	1.0,
	{"credits": 25},
	{"ore": 10}
)
```

This defines an ore mine that consumes `25` credits and produces `10` ore each month per building count.

### Designated Buildings

A designated building is a saved instance of a registered building type.

Each building stores:

- `id`: generated ID, such as `building_1`
- `type_id`: registered building type ID
- `count`: number of buildings represented by this designation
- `active`: whether it should run during production
- `metadata`: optional extra data for future systems, such as planet, tile, owner, or notes

Example:

```gdscript
var building_id = Industry.designate_building("ore_mine", 3)
```

With the `ore_mine` example above, this designation consumes `75` credits and produces `30` ore each month if requirements are available.

## Production Formula

For each active building:

```text
multiplier = building.count * building_type.production_rate
```

Requirements consumed:

```text
required_amount = requirement_amount * multiplier
```

Resources produced:

```text
produced_amount = produced_amount * multiplier
```

If any required resource is missing, the building is skipped for that month.

## Monthly Processing

Production is processed by:

```gdscript
var report = Industry.process_month()
```

`main.gd` calls this automatically after advancing the date by one month.

The report has this shape:

```gdscript
{
	"consumed": {
		"credits": 75.0
	},
	"produced": {
		"ore": 30.0
	},
	"blocked": {
		"building_2": "missing_requirements"
	},
	"processed_buildings": [
		"building_1"
	]
}
```

Blocked reasons currently include:

- `unknown_building_type`
- `missing_requirements`

## Public API

### Registering Types

```gdscript
Industry.register_building_type(
	building_type_id: String,
	display_name: String,
	production_rate: float,
	requirements: Dictionary,
	produces: Dictionary
) -> bool
```

Returns `true` if the type was registered.

Validation rules:

- `building_type_id` cannot be empty
- `production_rate` cannot be negative
- `produces` must contain at least one positive resource amount
- zero and negative resource amounts are ignored

### Reading Types

```gdscript
Industry.has_building_type(building_type_id: String) -> bool
Industry.get_building_type(building_type_id: String) -> Dictionary
Industry.get_building_types() -> Dictionary
```

Returned dictionaries are duplicated so callers cannot directly mutate internal type data.

### Designating Buildings

```gdscript
Industry.designate_building(
	building_type_id: String,
	count: int = 1,
	active: bool = true,
	metadata: Dictionary = {}
) -> String
```

Returns the new building ID, or an empty string if designation failed.

### Managing Buildings

```gdscript
Industry.remove_building(building_id: String) -> bool
Industry.set_building_active(building_id: String, active: bool) -> bool
Industry.set_building_count(building_id: String, count: int) -> bool
Industry.update_building(building_id: String, values: Dictionary) -> bool
Industry.get_building(building_id: String) -> Dictionary
Industry.get_buildings() -> Dictionary
```

`update_building()` ignores attempts to change `id` or `type_id`.

### Managing Resources

```gdscript
Industry.get_resource(resource_id: String) -> float
Industry.set_resource(resource_id: String, amount: float) -> bool
Industry.add_resource(resource_id: String, amount: float) -> bool
```

Resource amounts cannot go below zero.

The special resource ID `credits` maps to `GameData.CREDITS`. Other resources are stored in `GameData.RESOURCES`.

### Checking Production

```gdscript
Industry.can_run_building(building_id: String) -> bool
Industry.process_month() -> Dictionary
```

`can_run_building()` checks whether an active building has a valid type and enough requirements.

## Signals

```gdscript
signal building_type_registered(building_type_id: String)
signal building_designated(building_id: String, building_type_id: String)
signal building_removed(building_id: String, building_type_id: String)
signal production_processed(report: Dictionary)
signal resource_changed(resource_id: String, old_amount: float, new_amount: float)
```

These are intended for UI, notifications, debugging, and future gameplay systems.

## Persistence

The following industry state is saved through `GameData`:

- `GameData.RESOURCES`
- `GameData.INDUSTRY_BUILDINGS`
- `GameData.INDUSTRY_NEXT_BUILDING_ID`

Building type definitions are not saved. Register building types at startup before loading or using designated buildings.

## Example Setup

```gdscript
func _ready() -> void:
	Industry.register_building_type(
		"farm",
		"Farm",
		1.0,
		{"credits": 10},
		{"food": 25}
	)

	Industry.register_building_type(
		"factory",
		"Factory",
		0.5,
		{"credits": 50, "ore": 5},
		{"parts": 3}
	)

	Industry.set_resource("credits", 500)
	Industry.set_resource("ore", 20)

	Industry.designate_building("farm", 2)
	Industry.designate_building("factory", 1)
```
