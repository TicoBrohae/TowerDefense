## SplashTower.gd
## Fires explosive projectiles that deal area-of-effect damage.
## Lower per-target damage than BasicTower, but hits every enemy in the blast radius.
## Shines against dense clusters of enemies on a winding maze path.

extends "res://scripts/towers/Tower.gd"

var _projectile_scene: PackedScene = preload("res://scenes/projectiles/Projectile.tscn")

## Radius (pixels) of the explosion — hits all enemies within this circle on impact.
var splash_radius: float = 80.0

var _base_splash_radius: float = 0.0

func _ready() -> void:
	tower_type_id   = "splash"
	damage          = 20.0
	fire_rate       = 0.60
	range_radius    = 120.0
	projectile_speed= 150.0
	sell_value      = 62
	upgrade_cost    = 100
	_cache_base_stats()

func _cache_base_stats() -> void:
	super._cache_base_stats()
	_base_splash_radius = splash_radius

func _apply_special_upgrade(mult: float) -> void:
	splash_radius = _base_splash_radius * mult

func _shoot() -> void:
	if _current_target == null:
		return
	var proj: Projectile = _projectile_scene.instantiate()
	GameManager.projectiles_container.add_child(proj)
	proj.global_position = global_position
	proj.init(_current_target, damage, projectile_speed, Color(1.0, 0.5, 0.0))  # Orange
	# Tell the projectile to use area-of-effect on arrival
	proj.splash_radius = splash_radius

func _draw() -> void:
	# Stocky rounded look — a mortar-style tower
	draw_circle(Vector2.ZERO, 22.0, Color(0.5, 0.35, 0.15))  # Brown base
	draw_circle(Vector2.ZERO, 16.0, Color(0.65, 0.45, 0.20).lightened(upgrade_level * 0.07))
	# Short wide barrel pointing up-right
	draw_rect(Rect2(4, -18, 12, 22), Color(0.3, 0.3, 0.3))
	# Flame glow inside barrel mouth
	draw_circle(Vector2(10, -18), 5.0, Color(1.0, 0.6, 0.0, 0.7))

	# Upgrade pips
	for i in range(upgrade_level):
		draw_circle(Vector2(-10 + i * 10, 14), 3.0, Color.ORANGE)
