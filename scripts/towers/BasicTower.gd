## BasicTower.gd
## Fast-firing, balanced tower. Good all-rounder for the early game.
## Upgrade path: more damage → faster fire rate → even more damage + range.

extends "res://scripts/towers/Tower.gd"

# Preload the shared Projectile scene so we can spawn instances of it
var _projectile_scene: PackedScene = preload("res://scenes/projectiles/Projectile.tscn")

func _ready() -> void:
	tower_type_id   = "basic"
	damage          = 15.0
	fire_rate       = 1.2
	range_radius    = 130.0
	projectile_speed= 220.0
	sell_value      = 25
	upgrade_cost    = 60
	_cache_base_stats()

func _shoot() -> void:
	if _current_target == null:
		return
	# Instantiate a new projectile, configure it, then add to the projectiles layer
	var proj: Projectile = _projectile_scene.instantiate()
	GameManager.projectiles_container.add_child(proj)
	proj.global_position = global_position
	proj.init(_current_target, damage, projectile_speed, Color(1.0, 0.85, 0.0))  # Golden yellow

func _draw() -> void:
	## Gray square base with a yellow top plate and a small barrel pointing right.
	## The barrel doesn't rotate visually yet — that can be a future art pass.

	# Base plate (gray)
	draw_rect(Rect2(-22, -22, 44, 44), Color(0.55, 0.55, 0.55))
	# Top plate — colour brightens slightly at higher upgrade levels
	var top_color := Color(0.9, 0.7, 0.1).lightened(upgrade_level * 0.08)
	draw_rect(Rect2(-16, -16, 32, 32), top_color)
	# Cannon barrel
	draw_rect(Rect2(4, -5, 20, 10), Color(0.35, 0.35, 0.35))

	# Upgrade level pips drawn in the corners
	for i in range(upgrade_level):
		draw_circle(Vector2(-14 + i * 10, 10), 3.0, Color.YELLOW)
