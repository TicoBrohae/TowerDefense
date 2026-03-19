## GameManager.gd
## Global singleton (autoload) that holds all shared game state.
## Every script in the project can access this via "GameManager.gold", etc.
## Autoloads are registered in project.godot and always exist in the scene tree.

extends Node

# ---------------------------------------------------------------------------
# Signals — emitted when state changes so UI can update itself reactively
# ---------------------------------------------------------------------------
signal gold_changed(new_amount: int)
signal lives_changed(new_amount: int)
signal wave_changed(new_wave: int)
signal game_over()
signal game_won()

# ---------------------------------------------------------------------------
# Player resources — start values set in start_game()
# ---------------------------------------------------------------------------
var gold: int = 150
var lives: int = 20
var current_wave: int = 0
var score: int = 0
var game_active: bool = false

# ---------------------------------------------------------------------------
# Tower purchase costs (String key → gold cost)
# Towers reference these so the HUD and placement logic share one source of truth
# ---------------------------------------------------------------------------
const TOWER_COSTS: Dictionary = {
	"basic":  50,
	"slow":   75,
	"sniper": 100,
	"splash": 125,
}

# ---------------------------------------------------------------------------
# Scene-tree container references
# Set by Game.gd in _ready() so towers/enemies can add children to them
# ---------------------------------------------------------------------------
var enemies_container: Node     = null
var projectiles_container: Node = null
var towers_container: Node      = null   # Set by Game.gd; used by SaveManager._capture_towers()

# ---------------------------------------------------------------------------
# Gold management
# ---------------------------------------------------------------------------

## Try to spend gold. Returns true and deducts if affordable, false otherwise.
func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_changed.emit(gold)
		return true
	return false

## Add gold to the player's total (called when an enemy is killed).
func earn_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)

# ---------------------------------------------------------------------------
# Life management
# ---------------------------------------------------------------------------

## Called when an enemy reaches the exit. Deducts a life and checks game over.
func lose_life() -> void:
	lives -= 1
	lives_changed.emit(lives)
	if lives <= 0:
		game_active = false
		game_over.emit()

# ---------------------------------------------------------------------------
# Wave management
# ---------------------------------------------------------------------------

## Advance the wave counter. Called by WaveManager when a new wave starts.
func next_wave() -> void:
	current_wave += 1
	wave_changed.emit(current_wave)

# ---------------------------------------------------------------------------
# Game lifecycle
# ---------------------------------------------------------------------------

## Reset all state and begin a new game session.
func start_game() -> void:
	gold = 150
	lives = 20
	current_wave = 0
	score = 0
	game_active = true
	gold_changed.emit(gold)
	lives_changed.emit(lives)
	wave_changed.emit(current_wave)

## Add to the player's score (e.g., bonus for killing enemies quickly).
func add_score(amount: int) -> void:
	score += amount
