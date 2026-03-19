## RangeIndicator.gd
## A simple overlay node that draws a translucent circle showing a tower's
## attack range. Shown when the player clicks on a tower, hidden otherwise.
## The parent (Game.gd) moves this node to the selected tower's position
## and calls set_range() before making it visible.

extends Node2D

var _range_radius: float = 0.0

## Update the radius and force a redraw.
func set_range(radius: float) -> void:
	_range_radius = radius
	queue_redraw()

func _draw() -> void:
	if _range_radius <= 0.0:
		return
	# Filled translucent circle
	draw_circle(Vector2.ZERO, _range_radius, Color(1.0, 1.0, 1.0, 0.07))
	# Solid border ring so it's visible on both light and dark backgrounds
	draw_arc(Vector2.ZERO, _range_radius, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.55), 2.0)
