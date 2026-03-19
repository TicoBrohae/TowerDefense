## Game.gd
## The main game controller — the root script for the Game scene.
##
## Responsibilities:
##   - Handle mouse input for tower placement and selection
##   - Bridge signals between Grid, WaveManager, and HUD
##   - Store the "currently placing" and "currently selected" state
##   - Show/hide the range indicator ring

extends Node2D

# ---------------------------------------------------------------------------
# Tower type enum — maps UI choice to a scene
# ---------------------------------------------------------------------------
enum TowerType { NONE, BASIC, SLOW, SNIPER, SPLASH }

# ---------------------------------------------------------------------------
# Preloaded tower scenes
# ---------------------------------------------------------------------------
var _tower_scenes: Dictionary = {
	TowerType.BASIC:  preload("res://scenes/towers/BasicTower.tscn"),
	TowerType.SLOW:   preload("res://scenes/towers/SlowTower.tscn"),
	TowerType.SNIPER: preload("res://scenes/towers/SniperTower.tscn"),
	TowerType.SPLASH: preload("res://scenes/towers/SplashTower.tscn"),
}

## Maps the string names emitted by HUD to TowerType enum values
const TOWER_TYPE_MAP: Dictionary = {
	"basic":  TowerType.BASIC,
	"slow":   TowerType.SLOW,
	"sniper": TowerType.SNIPER,
	"splash": TowerType.SPLASH,
}

# ---------------------------------------------------------------------------
# Node references (set via @onready — Godot fills these at scene load time)
# ---------------------------------------------------------------------------
@onready var _grid:         Node2D     = $Grid
@onready var _towers:       Node       = $Towers
@onready var _enemies:      Node       = $Enemies
@onready var _projectiles:  Node       = $Projectiles
@onready var _wave_manager: WaveManager= $WaveManager
@onready var _hud:          CanvasLayer= $HUD
@onready var _range_indicator: Node2D  = $RangeIndicator

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------
var _placing_type: TowerType  = TowerType.NONE  # Which tower the player is placing
var _selected_tower: Tower    = null            # Tower currently selected for upgrade/sell

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	# Give GameManager references to the scene containers
	# so towers/enemies/projectiles are added to the right parent nodes
	GameManager.enemies_container     = _enemies
	GameManager.projectiles_container = _projectiles
	GameManager.towers_container      = _towers   # Needed by SaveManager._capture_towers()

	# Tell WaveManager where on the map enemies appear
	_wave_manager.spawn_point = _grid.cell_to_world(_grid.SPAWN_CELL)

	# Connect WaveManager signals → HUD
	_wave_manager.wave_completed.connect(_on_wave_completed)
	_wave_manager.all_waves_completed.connect(_on_all_waves_completed)

	# Connect HUD signals → this controller
	_hud.tower_type_selected.connect(_on_tower_type_selected)
	_hud.wave_start_requested.connect(_on_wave_start_requested)

	# Connect game-over signal
	GameManager.game_over.connect(_on_game_over)

	_range_indicator.visible = false

	# If SaveManager has data waiting (player pressed Load in the main menu),
	# restore from it; otherwise start a fresh game.
	if not SaveManager.pending_load.is_empty():
		_restore_from_save(SaveManager.pending_load)
		SaveManager.pending_load = {}
	else:
		GameManager.start_game()

# ---------------------------------------------------------------------------
# Save / load restore
# ---------------------------------------------------------------------------

func _restore_from_save(data: Dictionary) -> void:
	## Rebuild game state from a save file dict.
	## JSON numbers are always floats, so we cast everything to int where needed.

	# Restore player resources
	GameManager.gold         = int(data.get("gold",         150))
	GameManager.lives        = int(data.get("lives",        20))
	GameManager.current_wave = int(data.get("current_wave", 0))
	GameManager.score        = int(data.get("score",        0))
	GameManager.game_active  = true

	# Emit signals so the HUD refreshes immediately with the restored values
	GameManager.gold_changed.emit(GameManager.gold)
	GameManager.lives_changed.emit(GameManager.lives)
	GameManager.wave_changed.emit(GameManager.current_wave)

	# Tell WaveManager which wave was last completed so "Start Wave" picks up correctly
	_wave_manager.restore_wave(GameManager.current_wave)

	# Update the Start Wave button label to show the correct next wave number
	_hud.on_wave_completed(GameManager.current_wave + 1)

	# Restore placed towers
	for tower_data in data.get("towers", []):
		var cell := Vector2i(
			int(tower_data.get("cell_x", 0)),
			int(tower_data.get("cell_y", 0))
		)
		var type_str: String  = tower_data.get("type", "basic")
		var type_enum: TowerType = TOWER_TYPE_MAP.get(type_str, TowerType.BASIC)

		var tower: Tower = _tower_scenes[type_enum].instantiate()
		tower.cell_position   = cell
		tower.global_position = _grid.cell_to_world(cell)

		# add_child triggers tower._ready() which sets base stats —
		# restore_from_save() is called AFTER so it layers upgrades on top
		_towers.add_child(tower)
		_grid.place_tower(cell, tower)

		tower.restore_from_save(
			int(tower_data.get("upgrade_level", 0)),
			int(tower_data.get("sell_value",    tower.sell_value)),
			int(tower_data.get("target_mode",   0))
		)

		# Capture 'cell' by value so the lambda uses the right cell per iteration
		var captured_cell := cell
		tower.tower_sold.connect(func(_val): _grid.remove_tower(captured_cell))

# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return

	var mouse_pos: Vector2 = get_global_mouse_position()
	var cell: Vector2i     = _grid.world_to_cell(mouse_pos)

	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if _placing_type != TowerType.NONE:
				_try_place_tower(cell)
			else:
				_try_select_tower(mouse_pos, cell)

		MOUSE_BUTTON_RIGHT:
			# Right-click cancels placement mode or deselects
			_set_placing_type(TowerType.NONE)
			_deselect_tower()

# ---------------------------------------------------------------------------
# Tower placement
# ---------------------------------------------------------------------------

func _try_place_tower(cell: Vector2i) -> void:
	# Validate bounds
	if cell.x < 0 or cell.x >= _grid.GRID_WIDTH or cell.y < 0 or cell.y >= _grid.GRID_HEIGHT:
		return

	var type_key: String = _tower_type_to_string(_placing_type)
	var cost: int        = GameManager.TOWER_COSTS[type_key]

	if GameManager.gold < cost:
		return  # Not enough gold — TODO: flash gold label

	if not _grid.can_place_tower(cell):
		return  # Cell occupied or would block path

	# Spend gold and instantiate the tower
	GameManager.spend_gold(cost)
	var tower: Tower = _tower_scenes[_placing_type].instantiate()
	tower.cell_position  = cell
	tower.global_position = _grid.cell_to_world(cell)
	_towers.add_child(tower)
	_grid.place_tower(cell, tower)

	# Capture cell by value so the lambda still references the correct cell
	# if this code path is called multiple times (e.g., placing another tower)
	var placed_cell := cell
	tower.tower_sold.connect(func(_val): _grid.remove_tower(placed_cell))

func _tower_type_to_string(type: TowerType) -> String:
	match type:
		TowerType.BASIC:  return "basic"
		TowerType.SLOW:   return "slow"
		TowerType.SNIPER: return "sniper"
		TowerType.SPLASH: return "splash"
	return "basic"

# ---------------------------------------------------------------------------
# Tower selection
# ---------------------------------------------------------------------------

func _try_select_tower(_world_pos: Vector2, cell: Vector2i) -> void:
	if cell.x >= 0 and cell.x < _grid.GRID_WIDTH and cell.y >= 0 and cell.y < _grid.GRID_HEIGHT:
		var tower: Tower = _grid.tower_grid[cell.x][cell.y]
		if tower != null:
			_select_tower(tower)
			return
	_deselect_tower()

func _select_tower(tower: Tower) -> void:
	_selected_tower = tower
	_hud.show_tower_info(tower)
	# Position and show the range indicator
	_range_indicator.position = tower.global_position
	_range_indicator.set_range(tower.range_radius)
	_range_indicator.visible = true

func _deselect_tower() -> void:
	_selected_tower = null
	_hud.hide_tower_info()
	_range_indicator.visible = false

# ---------------------------------------------------------------------------
# Placing mode
# ---------------------------------------------------------------------------

func _set_placing_type(type: TowerType) -> void:
	_placing_type = type
	# Entering placement mode clears any selected tower
	if type != TowerType.NONE:
		_deselect_tower()

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_tower_type_selected(type_str: String) -> void:
	## HUD emitted a tower type — switch to placement mode
	if TOWER_TYPE_MAP.has(type_str):
		_set_placing_type(TOWER_TYPE_MAP[type_str])

func _on_wave_start_requested() -> void:
	_wave_manager.start_next_wave()

func _on_wave_completed(wave_num: int) -> void:
	_hud.on_wave_completed(wave_num + 1)

func _on_all_waves_completed() -> void:
	_hud.on_all_waves_done()
	# TODO: show victory screen

func _on_game_over() -> void:
	# TODO: show game over screen / disable input
	pass
