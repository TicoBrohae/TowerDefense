## Tower.gd
## Base class for all tower types.
## Subclasses (BasicTower, SlowTower, etc.) inherit from this and override:
##   _apply_upgrade() — what stat changes on each upgrade
##   _shoot()         — how the tower fires (projectile, splash, etc.)
##   _draw()          — how the tower looks

class_name Tower
extends Node2D

# ---------------------------------------------------------------------------
# Targeting modes — controls which enemy in range the tower prioritises
# ---------------------------------------------------------------------------
enum TargetMode {
	FIRST,    # Enemy furthest along the path (most dangerous)
	LAST,     # Enemy least far along the path
	STRONGEST,# Enemy with the most current HP
	WEAKEST,  # Enemy with the least current HP
	CLOSEST,  # Enemy nearest to this tower
}

# ---------------------------------------------------------------------------
# Tower stats — overridden by subclass _ready()
# ---------------------------------------------------------------------------
var damage: float          = 10.0   # Damage dealt per projectile
var fire_rate: float       = 1.0    # Shots per second
var range_radius: float    = 130.0  # Detection/attack radius in pixels
var projectile_speed: float= 220.0  # Speed of fired projectiles (px/sec)

# ---------------------------------------------------------------------------
# Economy
# ---------------------------------------------------------------------------
var sell_value: int   = 25   # Gold returned when selling (increases with upgrades)
var upgrade_cost: int = 75   # Gold cost for next upgrade
var upgrade_level: int = 0   # How many times this tower has been upgraded (0 = Lv1, 1 = Lv2, 2 = Lv3)
var max_upgrades: int  = 2   # Two additional upgrades beyond the placed level

## Stat multipliers by upgrade_level: Lv1 = ×1.0, Lv2 = ×1.2, Lv3 = ×1.5
const UPGRADE_MULTIPLIERS: Array = [1.0, 1.20, 1.50]

# ---------------------------------------------------------------------------
# Base stat cache — populated by _cache_base_stats() at end of each subclass _ready()
# ---------------------------------------------------------------------------
var _base_damage: float          = 0.0
var _base_fire_rate: float       = 0.0
var _base_range_radius: float    = 0.0
var _base_projectile_speed: float= 0.0

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var target_mode: TargetMode = TargetMode.FIRST  # Current targeting preference
var cell_position: Vector2i                     # Which grid cell this tower occupies
var tower_type_id: String = ""                  # "basic" | "slow" | "sniper" | "splash" — used by SaveManager

var _fire_timer: float  = 0.0    # Counts down to next allowed shot
var _current_target: Node2D = null  # The enemy currently being tracked

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal tower_sold(sell_value: int)

# ---------------------------------------------------------------------------
# Core loop
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	_fire_timer -= delta
	_update_target()

	# Fire when the timer expires AND we have a valid target
	if _current_target != null and _fire_timer <= 0.0:
		_shoot()
		_fire_timer = 1.0 / fire_rate  # Reset timer based on fire rate

# ---------------------------------------------------------------------------
# Targeting logic
# ---------------------------------------------------------------------------

func _update_target() -> void:
	## Check if the current target is still alive and in range.
	## If not, find a new target.
	if _current_target != null:
		# is_instance_valid() checks the object wasn't freed (enemy died)
		var still_alive := is_instance_valid(_current_target) and not _current_target.is_queued_for_deletion()
		var still_in_range := global_position.distance_to(_current_target.global_position) <= range_radius
		if not still_alive or not still_in_range:
			_current_target = null

	if _current_target == null:
		_current_target = _find_target()

func _find_target() -> Node2D:
	## Collect all enemies within range, then pick one based on target_mode.
	var all_enemies := get_tree().get_nodes_in_group("enemies")
	var in_range: Array[Node2D] = []

	for enemy in all_enemies:
		if global_position.distance_to(enemy.global_position) <= range_radius:
			in_range.append(enemy)

	if in_range.is_empty():
		return null

	# Lambda helpers used by Array.reduce() to find the best candidate
	match target_mode:
		TargetMode.FIRST:
			# path_progress is the enemy's current waypoint index — higher = closer to exit
			return in_range.reduce(
				func(a, b): return a if a.path_progress > b.path_progress else b
			)
		TargetMode.LAST:
			return in_range.reduce(
				func(a, b): return a if a.path_progress < b.path_progress else b
			)
		TargetMode.STRONGEST:
			return in_range.reduce(
				func(a, b): return a if a.current_health > b.current_health else b
			)
		TargetMode.WEAKEST:
			return in_range.reduce(
				func(a, b): return a if a.current_health < b.current_health else b
			)
		TargetMode.CLOSEST:
			return in_range.reduce(func(a, b):
				var da := global_position.distance_to(a.global_position)
				var db := global_position.distance_to(b.global_position)
				return a if da < db else b
			)

	return null  # Fallback (should never reach here)

# ---------------------------------------------------------------------------
# Shooting — overridden by each tower subclass
# ---------------------------------------------------------------------------

## Subclasses instantiate a Projectile scene and configure it here.
func _shoot() -> void:
	pass

# ---------------------------------------------------------------------------
# Upgrade system
# ---------------------------------------------------------------------------

## Snapshot base stats after a subclass _ready() sets them.
## Each subclass must call this at the very end of its _ready().
func _cache_base_stats() -> void:
	_base_damage          = damage
	_base_fire_rate       = fire_rate
	_base_range_radius    = range_radius
	_base_projectile_speed= projectile_speed

## Attempt to purchase the next upgrade.
## Returns true on success, false if max level or not enough gold.
func upgrade() -> bool:
	if upgrade_level >= max_upgrades:
		return false
	if not GameManager.spend_gold(upgrade_cost):
		return false

	upgrade_level += 1
	_apply_upgrade()

	# Increase sell value by half the upgrade cost (partial refund on sell)
	sell_value += int(upgrade_cost / 2)
	# Each successive upgrade costs more
	upgrade_cost = int(upgrade_cost * 1.5)
	queue_redraw()  # Refresh visual (some towers change appearance on upgrade)
	return true

## Scale all standard stats from the cached base by the appropriate multiplier.
## Lv2 = ×1.20 (+20% from base), Lv3 = ×1.50 (+50% from base).
func _apply_upgrade() -> void:
	var mult: float = UPGRADE_MULTIPLIERS[upgrade_level]
	damage           = _base_damage           * mult
	fire_rate        = _base_fire_rate        * mult
	range_radius     = _base_range_radius     * mult
	projectile_speed = _base_projectile_speed * mult
	_apply_special_upgrade(mult)

## Override in subclasses to scale tower-specific stats (e.g. splash_radius, slow_factor).
func _apply_special_upgrade(_mult: float) -> void:
	pass

# ---------------------------------------------------------------------------
# Sell
# ---------------------------------------------------------------------------

## Return gold and remove the tower from the scene.
func sell() -> void:
	tower_sold.emit(sell_value)
	GameManager.earn_gold(sell_value)
	queue_free()

# ---------------------------------------------------------------------------
# Targeting preference
# ---------------------------------------------------------------------------

## Change targeting mode at runtime (called by UI dropdown).
func set_target_mode(mode: TargetMode) -> void:
	target_mode = mode
	_current_target = null  # Force re-evaluation on next frame

# ---------------------------------------------------------------------------
# Save / load support
# ---------------------------------------------------------------------------

## Replay upgrade history to reconstruct stats without spending gold.
## Must be called AFTER the tower is added to the scene tree so _ready() has
## already set the base stats that the upgrades are applied on top of.
func restore_from_save(saved_upgrade_level: int, saved_sell_value: int,
		saved_target_mode: int) -> void:
	for i in range(saved_upgrade_level):
		upgrade_level += 1
		_apply_upgrade()
		# Mirror the cost multiplication that Tower.upgrade() does each level
		upgrade_cost = int(upgrade_cost * 1.5)
	# Use the exact sell_value from the save (avoids rounding drift)
	sell_value = saved_sell_value
	set_target_mode(saved_target_mode as TargetMode)
	queue_redraw()
