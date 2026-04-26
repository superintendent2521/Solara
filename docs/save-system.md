# Save System

The save backend is split across two scripts:

- `res://Scripts/storage_data.gd`
- `res://Scripts/game_data.gd`

`GameData` extends `StorageData` and is registered as an autoload in `project.godot`.

## Save Location

Save data is written to:

```text
user://save_data.json
```

In Godot, `user://` resolves to the platform-specific application data folder for the project.

## Saved Values

`GameData` defines all persistent keys in `_ready()` before loading the save file.

Current saved keys:

```gdscript
GameData.CREDITS
GameData.MONTH
GameData.YEAR
GameData.SPEED_1_ACTIVE
GameData.MONTH_TIMER
GameData.RESOURCES
GameData.INDUSTRY_BUILDINGS
GameData.INDUSTRY_NEXT_BUILDING_ID
```

Defaults:

```gdscript
{
	"credits": 2300,
	"month": 1,
	"year": 2030,
	"speed_1_active": false,
	"month_timer": 0.0,
	"resources": {},
	"industry_buildings": {},
	"industry_next_building_id": 1
}
```

## StorageData

`StorageData` is the generic key/value backend.

It tracks:

- `_values`: current runtime values
- `_defaults`: default values used by reset logic

It emits:

```gdscript
signal value_defined(key: StringName, value: Variant)
signal value_changed(key: StringName, old_value: Variant, new_value: Variant)
signal value_removed(key: StringName, old_value: Variant)
```

### Defining Values

```gdscript
define_value(key: StringName, default_value: Variant, overwrite_existing: bool = false) -> void
define_values(values: Dictionary, overwrite_existing: bool = false) -> void
```

Values must be defined before they can be set.

### Reading Values

```gdscript
has_value(key: StringName) -> bool
get_value(key: StringName, fallback: Variant = null) -> Variant
get_snapshot() -> Dictionary
get_save_snapshot() -> Dictionary
```

`get_value()` returns a duplicate for arrays and dictionaries so callers do not mutate stored data without calling `set_value()`.

`get_save_snapshot()` converts `StringName` keys into strings so they serialize cleanly to JSON.

### Writing Values

```gdscript
set_value(key: StringName, new_value: Variant) -> bool
set_values(values: Dictionary) -> void
change_value(key: StringName, amount: Variant) -> bool
remove_value(key: StringName) -> bool
reset_value(key: StringName) -> bool
reset_all() -> void
```

`set_value()` emits `value_changed` only when the value actually changes.

`change_value()` only supports numeric values.

## GameData

`GameData` adds JSON persistence on top of `StorageData`.

### Loading

`GameData.load_data()` runs during `_ready()`.

Load behavior:

1. If `user://save_data.json` does not exist, defaults remain active.
2. If the file cannot be read, a warning is pushed and defaults remain active.
3. If the file does not parse as a dictionary, a warning is pushed and defaults remain active.
4. Valid save entries are applied with `set_values()`.

Unknown keys in the save file are ignored because `StorageData.set_value()` only accepts defined keys.

### Saving

`GameData` marks itself dirty whenever `StorageData.value_changed` fires.

During `_process()`, dirty data is saved after:

```gdscript
SAVE_INTERVAL_SECONDS = 1.0
```

The save file is also written when Godot sends:

```gdscript
NOTIFICATION_WM_CLOSE_REQUEST
NOTIFICATION_PREDELETE
```

Manual save:

```gdscript
GameData.save_data()
```

Manual load:

```gdscript
GameData.load_data()
```

Reset save:

```gdscript
GameData.reset_save()
```

`reset_save()` restores defaults with `reset_all()` and immediately writes them to disk.

## Type Coercion

`StorageData.set_value()` coerces new values to the type of the default value for these types:

- `int`
- `float`
- `bool`
- `String`
- `StringName`

Dictionaries and arrays are stored as duplicated values but are not schema-validated.

## Working With Dictionaries

Because dictionaries are duplicated when read, update saved dictionary data like this:

```gdscript
var resources = GameData.get_value(GameData.RESOURCES)
resources["ore"] = 50
GameData.set_value(GameData.RESOURCES, resources)
```

Do not rely on mutating a returned dictionary without calling `set_value()`.

## JSON Shape

A save file currently looks like this:

```json
{
	"credits": 2300,
	"month": 1,
	"year": 2030,
	"speed_1_active": true,
	"month_timer": 0.0,
	"resources": {
		"ore": 50.0,
		"food": 25.0
	},
	"industry_buildings": {
		"building_1": {
			"id": "building_1",
			"type_id": "ore_mine",
			"count": 2,
			"active": true,
			"metadata": {}
		}
	},
	"industry_next_building_id": 2
}
```

## Adding New Saved Data

To add a new saved value:

1. Add a `StringName` constant to `GameData`.
2. Add its default value to `define_values()` in `GameData._ready()`.
3. Read and write it through `GameData.get_value()` and `GameData.set_value()`.

Example:

```gdscript
const PLAYER_NAME: StringName = &"player_name"

func _ready() -> void:
	define_values({
		PLAYER_NAME: "Commander",
	})
```

Existing save files that do not contain the new key will use the default.
