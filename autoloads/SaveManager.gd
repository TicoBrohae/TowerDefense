## SaveManager.gd
## Autoloaded singleton -- saves and loads game state as JSON files.
## Supports 3 independent slots stored in the OS app-data folder (user://).
##
## Save flow:
##   SaveManager.save_game(slot)       -> writes JSON to disk immediately
##
## Load flow:
##   SaveManager.load_game(slot)       -> reads file, stores data in pending_load
##   get_tree().change_scene_to_file() -> transition to Game.tscn
##   Game._ready()                     -> detects pending_load, calls _restore_from_save()

extends Node

const SAVE_SLOTS:   int = 3
const SAVE_VERSION: int = 1

# ---------------------------------------------------------------------------
# Pending load
# ---------------------------------------------------------------------------

## Populated by load_game() before a scene change.
## Game.gd reads this dict in _ready() to restore towers and state.
## Cleared by Game.gd once the restore is complete.
var pending_load: Dictionary = {}

# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------

func _save_path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot

func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_save_path(slot))

## Returns a lightweight summary dict for the Load Game panel.
## Keys: "wave" (int), "score" (int), "timestamp" (String).
## Returns an empty dict when the slot is empty or the file is unreadable.
func get_save_info(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var file := FileAccess.open(_save_path(slot), FileAccess.READ)
	if file == null:
		return {}
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary:
		return {}
	return {
		"wave":      int(data.get("current_wave", 0)),
		"score":     int(data.get("score",        0)),
		"timestamp": str(data.get("timestamp",    "")),
	}

# ---------------------------------------------------------------------------
# Saving
# ---------------------------------------------------------------------------

func save_game(slot: int) -> void:
	## Snapshot GameManager state and all placed towers, then write to disk.
	var data := {
		"version":      SAVE_VERSION,
		"timestamp":    Time.get_datetime_string_from_system(),
		"gold":         GameManager.gold,
		"lives":        GameManager.lives,
		"current_wave": GameManager.current_wave,
		"score":        GameManager.score,
		"towers":       _capture_towers(),
	}
	var file := FileAccess.open(_save_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot open %s for writing" % _save_path(slot))
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

func _capture_towers() -> Array:
	## Walk every child of the Towers container and serialise each to a dict.
	var result: Array = []
	if GameManager.towers_container == null:
		return result
	for tower in GameManager.towers_container.get_children():
		result.append({
			"cell_x":        tower.cell_position.x,
			"cell_y":        tower.cell_position.y,
			"type":          tower.tower_type_id,
			"upgrade_level": tower.upgrade_level,
			"target_mode":   tower.target_mode as int,
			"sell_value":    tower.sell_value,
		})
	return result

# ---------------------------------------------------------------------------
# Loading
# ---------------------------------------------------------------------------

func load_game(slot: int) -> bool:
	## Read save data into pending_load. Returns false if slot is empty or corrupt.
	if not has_save(slot):
		return false
	var file := FileAccess.open(_save_path(slot), FileAccess.READ)
	if file == null:
		return false
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary:
		return false
	pending_load = data
	return true

# ---------------------------------------------------------------------------
# Deletion
# ---------------------------------------------------------------------------

func delete_save(slot: int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_save_path(slot)))
