## Enemy.gd
## Base class for all enemy types.
## Subclasses set their stats in _ready() BEFORE calling super._ready()
## so that the base class can snapshot _base_speed correctly.
##
## Movement: enemies follow the grid path returned by Grid.get_path(),
## walking waypoint-to-waypoint. When the grid path changes (tower placed/sold),
## recalculate_path() is called on every living enemy via group call.

class_name Enemy
extends Node2D

# ---------------------------------------------------------------------------
# Stats — set by subclasses before calling super._ready()
# ---------------------------------------------------------------------------
var max_health: float  = 100.0  # Maximum HP
var current_health: float = 100.0
var move_speed: float  = 80.0   # Pixels per second (base speed before any slows)
var armor: float       = 0.0    # Fraction of damage absorbed (0 = none, 0.5 = 50%)
var gold_reward: int   = 10     # Gold given to player on death
var lives_cost: int    = 1      # Lives deducted if this enemy reaches the exit (bosses override to 3)

# ---------------------------------------------------------------------------
# Path-following state
# ---------------------------------------------------------------------------

## Index into _path array — how far along the route this enemy has progressed.
## Towers use this for FIRST/LAST targeting.
var path_progress: int = 0

var _path: Array[Vector2i] = []  # Copy of the current grid path
var _path_index: int = 0         # Which waypoint we're heading toward next
var _grid: Node2D = null         # Reference to the Grid node

# ---------------------------------------------------------------------------
# Slow effect state
# ---------------------------------------------------------------------------
var _base_speed: float = 0.0     # Cached unmodified speed (restored after slow expires)
var _slow_timer: float = 0.0
var _is_slowed: bool   = false

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal enemy_reached_exit(enemy)
signal enemy_died(enemy, gold_reward: int)

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	add_to_group("enemies")

	# Snapshot the base speed AFTER the subclass has set move_speed
	_base_speed = move_speed

	# Find the Grid node placed in the scene
	_grid = get_tree().get_first_node_in_group("grid")

	recalculate_path()

func _process(delta: float) -> void:
	# Tick slow timer — restore speed when it expires
	if _is_slowed:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			move_speed  = _base_speed
			_is_slowed  = false

	_move_along_path(delta)
	queue_redraw()  # Redraw health bar every frame

# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------

func _move_along_path(delta: float) -> void:
	## Walk toward the next waypoint. When close enough, advance to the next one.
	if _path_index >= _path.size():
		# No more waypoints — enemy has exited the map
		enemy_reached_exit.emit(self)
		queue_free()
		return

	var target_world: Vector2 = _grid.cell_to_world(_path[_path_index])
	var to_target: Vector2    = target_world - global_position
	var dist: float           = to_target.length()

	if dist < 4.0:
		# Close enough — snap to waypoint and advance
		global_position = target_world
		_path_index    += 1
		path_progress   = _path_index
	else:
		global_position += to_target.normalized() * move_speed * delta

## Called by Grid.gd (via group call) whenever the path changes.
## Keeps current progress so enemies don't backtrack.
func recalculate_path() -> void:
	if _grid == null:
		return
	_path = _grid.get_enemy_path()
	# Clamp the stored index to the new path length in case the path got shorter
	_path_index   = clampi(_path_index, 0, _path.size())
	path_progress = _path_index

# ---------------------------------------------------------------------------
# Damage & slow
# ---------------------------------------------------------------------------

## Apply damage to this enemy, reduced by armor.
func take_damage(damage: float) -> void:
	var actual := damage * (1.0 - armor)
	current_health -= actual
	if current_health <= 0.0:
		_die()

## Apply a speed-reduction slow effect.
## Stacks by always taking the more severe value and the longer duration.
func apply_slow(factor: float, duration: float) -> void:
	var slowed_speed := _base_speed * (1.0 - factor)
	# Only apply if it slows MORE than the current slow
	if slowed_speed < move_speed or not _is_slowed:
		move_speed = slowed_speed
	_slow_timer = maxf(_slow_timer, duration)
	_is_slowed  = true

func _die() -> void:
	enemy_died.emit(self, gold_reward)
	queue_free()

# ---------------------------------------------------------------------------
# Visual — health bar drawn above the enemy body
# ---------------------------------------------------------------------------

func _draw() -> void:
	## Called every frame via queue_redraw() in _process().
	## Drawn in local space (0,0 is the enemy's centre).
	var bar_w:   float = 44.0
	var bar_h:   float = 5.0
	var bar_pos := Vector2(-bar_w * 0.5, -34.0)   # Offset above sprite
	var hp_pct:  float = current_health / max_health

	# Background (dark red)
	draw_rect(Rect2(bar_pos, Vector2(bar_w, bar_h)), Color(0.4, 0.0, 0.0))
	# Health fill (green → red as HP drops)
	var bar_color := Color(lerp(1.0, 0.0, hp_pct), lerp(0.0, 0.8, hp_pct), 0.0)
	draw_rect(Rect2(bar_pos, Vector2(bar_w * hp_pct, bar_h)), bar_color)
