## WaveManager.gd
## Controls enemy wave spawning.
## Each wave is defined as an array of spawn groups.
## A spawn group specifies: which enemy type, how many, and the delay between them.
##
## After all enemies in a wave die or exit, the wave is considered complete
## and the player may start the next wave manually via the HUD button.

class_name WaveManager
extends Node

# ---------------------------------------------------------------------------
# Wave definitions
# Each entry is an Array of Dictionaries:
#   type     : String  — "normal" | "fast" | "armored" | "boss"
#   count    : int     — how many of this type to spawn
#   interval : float   — seconds between each spawn within this group
# ---------------------------------------------------------------------------
const WAVE_DATA: Array = [
	# Wave 1 — Tutorial: just Normal enemies
	[{"type": "normal", "count": 10, "interval": 1.00}],

	# Wave 2 — Introduce Fast enemies
	[{"type": "normal", "count":  8, "interval": 0.90},
	 {"type": "fast",   "count":  5, "interval": 0.60}],

	# Wave 3 — Introduce Armored
	[{"type": "normal",  "count": 10, "interval": 0.80},
	 {"type": "armored", "count":  4, "interval": 1.20}],

	# Wave 4 — First Boss
	[{"type": "normal",  "count": 12, "interval": 0.70},
	 {"type": "fast",    "count":  8, "interval": 0.50},
	 {"type": "boss",    "count":  1, "interval": 0.00}],

	# Wave 5 — All types mixed
	[{"type": "normal",  "count": 15, "interval": 0.60},
	 {"type": "armored", "count":  8, "interval": 1.00},
	 {"type": "fast",    "count": 10, "interval": 0.45}],

	# Wave 6 — Armored surge
	[{"type": "armored", "count": 15, "interval": 0.90},
	 {"type": "boss",    "count":  2, "interval": 5.00}],

	# Wave 7 — Speed round
	[{"type": "fast",    "count": 25, "interval": 0.35},
	 {"type": "normal",  "count": 10, "interval": 0.60}],

	# Wave 8 — Final wave
	[{"type": "normal",  "count": 20, "interval": 0.55},
	 {"type": "fast",    "count": 15, "interval": 0.35},
	 {"type": "armored", "count": 12, "interval": 0.80},
	 {"type": "boss",    "count":  3, "interval": 6.00}],
]

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal all_waves_completed()

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

## Preloaded enemy scenes — loaded once in _ready() for efficiency
var _enemy_scenes: Dictionary = {}

var _wave_index: int       = -1    # Which wave we are on (-1 = not started)
var _spawn_queue: Array    = []    # Remaining enemies yet to spawn this wave
var _spawn_timer: float    = 0.0   # Time since last spawn
var _next_delay: float     = 0.0   # How long to wait before next spawn
var _enemies_alive: int    = 0     # Enemies still on the field this wave
var _wave_active: bool     = false # True while a wave is in progress

## World-space position where enemies appear (set from Grid.SPAWN_CELL)
var spawn_point: Vector2 = Vector2.ZERO

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	add_to_group("wave_manager")  # HUD calls start_next_wave() via this group
	_enemy_scenes["normal"]  = preload("res://scenes/enemies/NormalEnemy.tscn")
	_enemy_scenes["fast"]    = preload("res://scenes/enemies/FastEnemy.tscn")
	_enemy_scenes["armored"] = preload("res://scenes/enemies/ArmoredEnemy.tscn")
	_enemy_scenes["boss"]    = preload("res://scenes/enemies/BossEnemy.tscn")

func _process(delta: float) -> void:
	if not _wave_active or _spawn_queue.is_empty():
		return

	_spawn_timer += delta
	if _spawn_timer >= _next_delay:
		_spawn_timer = 0.0
		var entry: Dictionary = _spawn_queue.pop_front()
		_spawn_enemy(entry["type"])
		_next_delay = entry["interval"]

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Called by the HUD "Start Wave" button (via group call).
func start_next_wave() -> void:
	if _wave_active:
		return  # Ignore if a wave is already running

	_wave_index += 1
	if _wave_index >= WAVE_DATA.size():
		all_waves_completed.emit()
		GameManager.game_won.emit()
		return

	_build_spawn_queue(_wave_index)
	_wave_active   = true
	_spawn_timer   = 0.0
	_next_delay    = 0.5   # Short pause before first enemy appears

	GameManager.next_wave()
	wave_started.emit(_wave_index + 1)

## Total number of waves defined.
func get_total_waves() -> int:
	return WAVE_DATA.size()

## Restore internal state after loading a save.
## completed_wave_count = GameManager.current_wave (how many waves are done).
## After this call, pressing "Start Wave" will begin the correct next wave.
func restore_wave(completed_wave_count: int) -> void:
	_wave_index    = completed_wave_count - 1   # -1 so the next += 1 lands on the right index
	_wave_active   = false
	_spawn_queue   = []
	_enemies_alive = 0

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

func _build_spawn_queue(wave_idx: int) -> void:
	## Flatten the wave data into a sequential list of spawn commands.
	## Enemies of different types are interleaved (shuffled) so the wave
	## feels mixed rather than arriving in blocks.
	_spawn_queue   = []
	_enemies_alive = 0

	for group in WAVE_DATA[wave_idx]:
		for _i in range(group["count"]):
			_spawn_queue.append({"type": group["type"], "interval": group["interval"]})
			_enemies_alive += 1

	# Shuffle so enemy types mix together
	_spawn_queue.shuffle()

func _spawn_enemy(type: String) -> void:
	if not _enemy_scenes.has(type):
		push_error("WaveManager: unknown enemy type '%s'" % type)
		return

	var enemy = _enemy_scenes[type].instantiate()
	enemy.global_position = spawn_point
	GameManager.enemies_container.add_child(enemy)

	# Connect signals so we can track when enemies die or escape
	enemy.enemy_died.connect(_on_enemy_died)
	enemy.enemy_reached_exit.connect(_on_enemy_reached_exit)

func _on_enemy_died(_enemy, reward: int) -> void:
	GameManager.earn_gold(reward)
	GameManager.add_score(reward * 10)
	_enemies_alive -= 1
	_check_wave_complete()

func _on_enemy_reached_exit(enemy) -> void:
	# lives_cost is 1 for normal enemies, 3 for bosses (set in BossEnemy._ready())
	for _i in range(enemy.lives_cost):
		GameManager.lose_life()
	_enemies_alive -= 1
	_check_wave_complete()

func _check_wave_complete() -> void:
	if _spawn_queue.is_empty() and _enemies_alive <= 0:
		_wave_active = false
		wave_completed.emit(_wave_index + 1)
