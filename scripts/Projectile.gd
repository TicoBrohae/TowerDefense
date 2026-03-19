## Projectile.gd
## A single projectile fired by a tower toward a target enemy.
## Homing — it tracks the enemy's current position each frame.
## If the target dies before impact, the projectile simply disappears.
##
## Optional properties (set after init() to enable effects):
##   splash_radius — if > 0, damages all enemies within this radius on hit
##   slow_factor   — if > 0, applies a speed reduction on hit
##   slow_duration — how long the slow lasts (seconds)

class_name Projectile
extends Node2D

# ---------------------------------------------------------------------------
# Configuration — set via init() or directly after instantiation
# ---------------------------------------------------------------------------
var damage: float        = 10.0
var speed: float         = 220.0
var splash_radius: float = 0.0    # 0 = single-target only
var slow_factor: float   = 0.0    # 0 = no slow  (0.4 = 40% speed reduction)
var slow_duration: float = 0.0    # Seconds the slow lasts
var color: Color         = Color.WHITE

var _target: Node2D = null

# ---------------------------------------------------------------------------
# Initialisation
# ---------------------------------------------------------------------------

## Set up the projectile after instantiating the scene.
## Must be called before the projectile is added to the tree,
## or immediately after (before the first _process tick).
func init(target: Node2D, dmg: float, spd: float, clr: Color = Color.WHITE) -> void:
	_target  = target
	damage   = dmg
	speed    = spd
	color    = clr

# ---------------------------------------------------------------------------
# Movement & hit detection
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	# If target has been freed (enemy died), remove the projectile
	if not is_instance_valid(_target) or _target.is_queued_for_deletion():
		queue_free()
		return

	var to_target: Vector2 = _target.global_position - global_position
	var dist: float        = to_target.length()

	if dist < 8.0:
		# Close enough — register hit
		_on_hit()
	else:
		# Move toward the target and rotate to face it
		global_position += to_target.normalized() * speed * delta
		rotation = to_target.angle()

# ---------------------------------------------------------------------------
# Hit resolution
# ---------------------------------------------------------------------------

func _on_hit() -> void:
	if splash_radius > 0.0:
		# Area-of-effect: damage every enemy within the splash circle
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if global_position.distance_to(enemy.global_position) <= splash_radius:
				_apply_effects(enemy)
		# Optional: draw a brief explosion visual here in the future
	else:
		# Single target
		if is_instance_valid(_target):
			_apply_effects(_target)
	queue_free()

func _apply_effects(enemy: Node2D) -> void:
	## Deal damage and optionally slow the enemy.
	enemy.take_damage(damage)
	if slow_factor > 0.0 and enemy.has_method("apply_slow"):
		enemy.apply_slow(slow_factor, slow_duration)

# ---------------------------------------------------------------------------
# Visual — a simple coloured circle
# ---------------------------------------------------------------------------

func _draw() -> void:
	draw_circle(Vector2.ZERO, 5.0, color)
	# Outline for visibility against both light and dark backgrounds
	draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 12, Color(0, 0, 0, 0.4), 1.5)
