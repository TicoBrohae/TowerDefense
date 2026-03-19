## Grid.gd
## Manages the game board: a 2D grid of cells where towers can be placed.
## Uses Godot's built-in AStarGrid2D for pathfinding.
##
## Key responsibilities:
##   - Track which cells are occupied by towers
##   - Validate tower placement (would it block the only path?)
##   - Recalculate enemy path after every tower placement/removal
##   - Draw the grid lines, path highlight, and spawn/exit markers

extends Node2D

# ---------------------------------------------------------------------------
# Grid dimensions and layout constants
# ---------------------------------------------------------------------------
const GRID_WIDTH: int  = 20   # Number of columns (horizontal cells)
const GRID_HEIGHT: int = 20   # Number of rows    (vertical cells)
const CELL_SIZE: int   = 45   # Pixel size of each square cell (900x900 fits 1080x910 play area)

# Spawn (entrance) and exit cells — enemies travel from left to right
# Row 10 is the vertical centre of a 20-row grid (0-indexed)
const SPAWN_CELL: Vector2i = Vector2i(0,  10)
const EXIT_CELL:  Vector2i = Vector2i(19, 10)

# ---------------------------------------------------------------------------
# Runtime data
# ---------------------------------------------------------------------------

## Godot's built-in A* grid pathfinder
var astar: AStarGrid2D

## 2D array [x][y] storing the Tower node occupying that cell, or null if empty
var tower_grid: Array = []

## The current shortest path from spawn to exit as an array of cell coordinates.
## Updated every time a tower is placed or removed.
var _current_path: Array[Vector2i] = []

# ---------------------------------------------------------------------------
# Initialisation
# ---------------------------------------------------------------------------

func _ready() -> void:
	add_to_group("grid")  # Lets enemies find this node via get_first_node_in_group("grid")
	_init_tower_grid()
	_init_astar()
	_recalculate_path()

func _init_tower_grid() -> void:
	## Build a blank 2D array (all nulls = no towers placed yet)
	tower_grid = []
	for x in range(GRID_WIDTH):
		tower_grid.append([])
		for _y in range(GRID_HEIGHT):
			tower_grid[x].append(null)

func _init_astar() -> void:
	## Set up the A* grid to match our game grid.
	## diagonal_mode = NEVER means enemies only move in 4 cardinal directions.
	astar = AStarGrid2D.new()
	astar.region        = Rect2i(0, 0, GRID_WIDTH, GRID_HEIGHT)
	astar.cell_size     = Vector2(CELL_SIZE, CELL_SIZE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()

# ---------------------------------------------------------------------------
# Path calculation
# ---------------------------------------------------------------------------

func _recalculate_path() -> void:
	## Ask A* for the best path from spawn to exit.
	## is_empty() means no path exists (all routes are blocked).
	_current_path = astar.get_id_path(SPAWN_CELL, EXIT_CELL)
	queue_redraw()  # Redraw the path highlight on screen

## Public accessor so enemies can read the current path.
## Named get_enemy_path() to avoid conflicting with the built-in Node.get_path() -> NodePath.
func get_enemy_path() -> Array[Vector2i]:
	return _current_path

# ---------------------------------------------------------------------------
# Tower placement helpers
# ---------------------------------------------------------------------------

## Returns true if a tower CAN be legally placed on the given cell.
## Rules: cell must be in bounds, empty, not spawn/exit,
##        and placing it must not completely cut off the path.
func can_place_tower(cell: Vector2i) -> bool:
	# Bounds check
	if cell.x < 0 or cell.x >= GRID_WIDTH or cell.y < 0 or cell.y >= GRID_HEIGHT:
		return false
	# Spawn and exit cells are always open
	if cell == SPAWN_CELL or cell == EXIT_CELL:
		return false
	# Cell already has a tower
	if tower_grid[cell.x][cell.y] != null:
		return false
	# Temporarily mark the cell as solid and test if a path still exists
	astar.set_point_solid(cell, true)
	var test_path: Array[Vector2i] = astar.get_id_path(SPAWN_CELL, EXIT_CELL)
	if test_path.is_empty():
		# This would trap enemies — undo and reject placement
		astar.set_point_solid(cell, false)
		return false
	# Valid — undo the test block (place_tower() will re-block it permanently)
	astar.set_point_solid(cell, false)
	return true

## Officially place a tower on the grid after spending gold.
## Blocks the cell in the pathfinder and tells all enemies to re-route.
func place_tower(cell: Vector2i, tower_node: Node2D) -> void:
	tower_grid[cell.x][cell.y] = tower_node
	astar.set_point_solid(cell, true)
	_recalculate_path()
	# All active enemies must find new routes around the newly placed tower
	get_tree().call_group("enemies", "recalculate_path")

## Remove a tower from the grid (called on sell).
func remove_tower(cell: Vector2i) -> void:
	tower_grid[cell.x][cell.y] = null
	astar.set_point_solid(cell, false)
	_recalculate_path()
	get_tree().call_group("enemies", "recalculate_path")

# ---------------------------------------------------------------------------
# Coordinate conversion
# ---------------------------------------------------------------------------

## Convert a world-space position to the grid cell it falls within.
## Uses to_local() so the grid node can be positioned anywhere in the scene.
func world_to_cell(world_pos: Vector2) -> Vector2i:
	var local_pos: Vector2 = to_local(world_pos)
	return Vector2i(int(local_pos.x / CELL_SIZE), int(local_pos.y / CELL_SIZE))

## Convert a grid cell to the world-space centre of that cell.
func cell_to_world(cell: Vector2i) -> Vector2:
	var local_pos := Vector2(
		cell.x * CELL_SIZE + CELL_SIZE * 0.5,
		cell.y * CELL_SIZE + CELL_SIZE * 0.5
	)
	return to_global(local_pos)

# ---------------------------------------------------------------------------
# Rendering
# ---------------------------------------------------------------------------

func _draw() -> void:
	## _draw() is Godot's 2D drawing callback — called by queue_redraw().
	## Everything here is drawn in the node's LOCAL coordinate space.

	# --- Background ---
	draw_rect(
		Rect2(0, 0, GRID_WIDTH * CELL_SIZE, GRID_HEIGHT * CELL_SIZE),
		Color(0.13, 0.17, 0.13)  # Dark green-grey ground
	)

	# --- Path highlight (so players can see the enemy route) ---
	for i in range(_current_path.size() - 1):
		var from := Vector2(
			_current_path[i].x * CELL_SIZE + CELL_SIZE * 0.5,
			_current_path[i].y * CELL_SIZE + CELL_SIZE * 0.5
		)
		var to := Vector2(
			_current_path[i + 1].x * CELL_SIZE + CELL_SIZE * 0.5,
			_current_path[i + 1].y * CELL_SIZE + CELL_SIZE * 0.5
		)
		draw_line(from, to, Color(0.3, 0.7, 0.3, 0.45), 20.0)

	# --- Grid lines ---
	var grid_color := Color(0.25, 0.28, 0.25, 0.6)
	for x in range(GRID_WIDTH + 1):
		draw_line(
			Vector2(x * CELL_SIZE, 0),
			Vector2(x * CELL_SIZE, GRID_HEIGHT * CELL_SIZE),
			grid_color, 1.0
		)
	for y in range(GRID_HEIGHT + 1):
		draw_line(
			Vector2(0, y * CELL_SIZE),
			Vector2(GRID_WIDTH * CELL_SIZE, y * CELL_SIZE),
			grid_color, 1.0
		)

	# --- Spawn marker (green outline) ---
	draw_rect(
		Rect2(SPAWN_CELL.x * CELL_SIZE, SPAWN_CELL.y * CELL_SIZE, CELL_SIZE, CELL_SIZE),
		Color.GREEN, false, 3.0
	)
	# --- Exit marker (red outline) ---
	draw_rect(
		Rect2(EXIT_CELL.x * CELL_SIZE, EXIT_CELL.y * CELL_SIZE, CELL_SIZE, CELL_SIZE),
		Color.RED, false, 3.0
	)
