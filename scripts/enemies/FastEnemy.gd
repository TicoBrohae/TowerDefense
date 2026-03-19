## FastEnemy.gd
## Low health but moves nearly twice as fast as a Normal enemy.
## Difficult to hit with slow-firing towers — SlowTowers counter it well.

extends "res://scripts/enemies/Enemy.gd"

func _ready() -> void:
	max_health    = 55.0
	current_health= max_health
	move_speed    = 105.0   # Much faster than normal
	armor         = 0.0
	gold_reward   = 12
	super._ready()

func _draw() -> void:
	# Cyan diamond shape — visually distinct and looks quick
	var pts := PackedVector2Array([
		Vector2(0, -16), Vector2(13, 0), Vector2(0, 16), Vector2(-13, 0)
	])
	draw_colored_polygon(pts, Color(0.0, 0.85, 0.90))
	draw_polyline(
		PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
		Color(0.0, 0.5, 0.6), 2.0
	)
	# Speed streak lines
	draw_line(Vector2(-6, -8), Vector2(-18, -5), Color(0.5, 1.0, 1.0, 0.5), 1.5)
	draw_line(Vector2(-6,  0), Vector2(-20,  0), Color(0.5, 1.0, 1.0, 0.5), 1.5)
	draw_line(Vector2(-6,  8), Vector2(-18,  5), Color(0.5, 1.0, 1.0, 0.5), 1.5)
	super._draw()
