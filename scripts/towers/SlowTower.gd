## SlowTower.gd
## Fires ice projectiles that slow enemies on hit.
## Deals low damage but the slow effect is invaluable for letting
## other towers get more shots in.

extends "res://scripts/towers/Tower.gd"

var _projectile_scene: PackedScene = preload("res://scenes/projectiles/Projectile.tscn")

# Slow properties — stored here so _apply_upgrade() can modify them
# and _shoot() can read them when creating the projectile
var slow_factor: float   = 0.40  # 40% speed reduction
var slow_duration: float = 2.0   # Lasts 2 seconds

var _base_slow_factor: float   = 0.0
var _base_slow_duration: float = 0.0

func _ready() -> void:
	tower_type_id   = "slow"
	damage          = 5.0
	fire_rate       = 0.8
	range_radius    = 140.0
	projectile_speed= 180.0
	sell_value      = 37
	upgrade_cost    = 75
	_cache_base_stats()

func _cache_base_stats() -> void:
	super._cache_base_stats()
	_base_slow_factor   = slow_factor
	_base_slow_duration = slow_duration

func _apply_special_upgrade(mult: float) -> void:
	slow_factor   = _base_slow_factor   * mult
	slow_duration = _base_slow_duration * mult

func _shoot() -> void:
	if _current_target == null:
		return
	var proj: Projectile = _projectile_scene.instantiate()
	GameManager.projectiles_container.add_child(proj)
	proj.global_position = global_position
	proj.init(_current_target, damage, projectile_speed, Color(0.3, 0.6, 1.0))  # Ice blue
	# Apply the slow parameters from this tower's current upgrade state
	proj.slow_factor   = slow_factor
	proj.slow_duration = slow_duration

func _draw() -> void:
	# Blue square base with icy crystal shape on top
	draw_rect(Rect2(-22, -22, 44, 44), Color(0.4, 0.4, 0.55))
	draw_rect(Rect2(-16, -16, 32, 32), Color(0.2, 0.5, 0.9).lightened(upgrade_level * 0.07))
	# Crystal "barrel" — a diamond shape pointing right
	var pts := PackedVector2Array([
		Vector2(6, 0), Vector2(20, -6), Vector2(26, 0), Vector2(20, 6)
	])
	draw_colored_polygon(pts, Color(0.5, 0.8, 1.0, 0.9))

	# Upgrade pips
	for i in range(upgrade_level):
		draw_circle(Vector2(-14 + i * 10, 10), 3.0, Color.CYAN)
