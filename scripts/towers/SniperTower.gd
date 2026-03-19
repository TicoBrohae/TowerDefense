## SniperTower.gd
## Extremely long range, high single-target damage, very slow fire rate.
## Best placed at the back where its range can cover the whole maze.
## Struggles against fast enemies — pair with a SlowTower for best results.

extends "res://scripts/towers/Tower.gd"

var _projectile_scene: PackedScene = preload("res://scenes/projectiles/Projectile.tscn")

func _ready() -> void:
	tower_type_id   = "sniper"
	damage          = 60.0
	fire_rate       = 0.40
	range_radius    = 300.0
	projectile_speed= 500.0
	sell_value      = 50
	upgrade_cost    = 100
	target_mode     = TargetMode.STRONGEST
	_cache_base_stats()

func _shoot() -> void:
	if _current_target == null:
		return
	var proj: Projectile = _projectile_scene.instantiate()
	GameManager.projectiles_container.add_child(proj)
	proj.global_position = global_position
	proj.init(_current_target, damage, projectile_speed, Color(1.0, 0.3, 0.1))  # Orange-red

func _draw() -> void:
	# Tall, narrow silhouette to suggest a sniper tower
	draw_rect(Rect2(-14, -28, 28, 56), Color(0.45, 0.30, 0.20))   # Brown stone base
	draw_rect(Rect2(-10, -24, 20, 48), Color(0.55, 0.38, 0.26).lightened(upgrade_level * 0.08))
	# Long thin barrel
	draw_rect(Rect2(8, -3, 32, 6), Color(0.25, 0.25, 0.25))
	# Scope dot
	draw_circle(Vector2(22, 0), 3.0, Color(0.8, 0.0, 0.0))

	# Upgrade pips
	for i in range(upgrade_level):
		draw_circle(Vector2(-8 + i * 8, 18), 3.0, Color.ORANGE_RED)
