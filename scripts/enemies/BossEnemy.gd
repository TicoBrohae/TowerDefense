## BossEnemy.gd
## High HP, moderate armor, normal speed. A massive threat if it reaches the exit.
## Costs the player 3 lives if it escapes rather than the usual 1.
## Worth significant gold on kill.

extends "res://scripts/enemies/Enemy.gd"

func _ready() -> void:
	max_health    = 500.0
	current_health= max_health
	move_speed    = 50.0    # Slow but tanky
	armor         = 0.25    # 25% damage reduction
	gold_reward   = 80
	# Boss costs 3 lives if it escapes — WaveManager reads this property
	lives_cost    = 3
	super._ready()

## Bosses resist slows but aren't immune — 30% reduction of the slow factor.
func apply_slow(factor: float, duration: float) -> void:
	super.apply_slow(factor * 0.70, duration)

func _draw() -> void:
	# Large dark-red pentagon — pentagons feel threatening
	var pts := PackedVector2Array()
	for i in range(5):
		# Start at the top (subtract quarter turn so first point points up)
		var angle: float = i * TAU / 5.0 - TAU / 4.0
		pts.append(Vector2(cos(angle) * 22.0, sin(angle) * 22.0))
	draw_colored_polygon(pts, Color(0.70, 0.08, 0.08))
	draw_polyline(
		PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[0]]),
		Color(1.0, 0.20, 0.20), 3.0
	)
	# Glowing centre circle
	draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.4, 0.0, 0.8))
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.9, 0.0))
	super._draw()
