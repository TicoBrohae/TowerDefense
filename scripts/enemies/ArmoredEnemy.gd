## ArmoredEnemy.gd
## Moves slightly slower than a Normal enemy but absorbs 40% of all incoming damage.
## Also partially resists slow effects (armor blocks some of the slow).
## Requires a Sniper or heavy investment of Basic towers to bring down.

extends "res://scripts/enemies/Enemy.gd"

func _ready() -> void:
	max_health    = 100.0
	current_health= max_health
	move_speed    = 65.0     # Slightly slower
	armor         = 0.40     # 40% damage reduction
	gold_reward   = 20
	super._ready()

## Armored enemies resist slow effects — their heavy plating absorbs 50% of the slow factor.
func apply_slow(factor: float, duration: float) -> void:
	super.apply_slow(factor * 0.50, duration)

func _draw() -> void:
	# Steel-grey hexagon — the hexagonal shape suggests armour plating
	var pts := PackedVector2Array()
	for i in range(6):
		var angle: float = i * TAU / 6.0
		pts.append(Vector2(cos(angle) * 17.0, sin(angle) * 17.0))
	draw_colored_polygon(pts, Color(0.45, 0.50, 0.55))
	# Armour highlights
	draw_polyline(
		PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[4], pts[5], pts[0]]),
		Color(0.75, 0.80, 0.85), 2.5
	)
	# Small shield icon in centre
	draw_rect(Rect2(-5, -7, 10, 12), Color(0.60, 0.65, 0.70), true)
	super._draw()
