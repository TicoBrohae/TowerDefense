## NormalEnemy.gd
## Standard enemy — the baseline all other types are balanced around.
## Low health, moderate speed, no armor. Worth a small gold reward.

extends "res://scripts/enemies/Enemy.gd"

func _ready() -> void:
	# Set stats BEFORE calling super._ready() so _base_speed is snapshotted correctly
	max_health    = 50.0
	current_health= max_health
	move_speed    = 50.0
	armor         = 0.0
	gold_reward   = 10
	super._ready()

func _draw() -> void:
	# Green circle body
	draw_circle(Vector2.ZERO, 14.0, Color(0.20, 0.75, 0.20))
	draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 32, Color(0.0, 0.45, 0.0), 2.0)
	# Health bar (from base class)
	super._draw()
