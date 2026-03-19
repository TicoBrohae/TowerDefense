## SettingsManager.gd
## Autoloaded singleton — persists audio, display, and UI scale preferences.
## Loads from user://settings.cfg on startup and applies immediately.
## Each setting is applied live as the player changes it in the Options menu.

extends Node

const SETTINGS_PATH := "user://settings.cfg"

# ---------------------------------------------------------------------------
# Available resolutions listed in the Options menu
# ---------------------------------------------------------------------------
const RESOLUTIONS: Array = [
	Vector2i(1280, 720),
	Vector2i(1280, 960),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

const RESOLUTION_LABELS: Array = [
	"1280 x 720   (HD)",
	"1280 x 960",
	"1600 x 900",
	"1920 x 1080  (FHD)",
	"2560 x 1440  (QHD)",
	"3840 x 2160  (4K)",
]

# ---------------------------------------------------------------------------
# Settings values — these are the defaults on first run
# ---------------------------------------------------------------------------
var master_volume:    float = 1.0   # 0.0 = mute  →  1.0 = full volume
var music_volume:     float = 0.8
var sfx_volume:       float = 1.0
var fullscreen:       bool  = false
var resolution_index: int   = 3     # Default: 1920 × 1080
var ui_scale:         float = 1.0   # 0.5 (smaller UI) → 2.0 (larger UI)

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_ensure_audio_buses()
	var first_run := not FileAccess.file_exists(SETTINGS_PATH)
	load_settings()
	if first_run:
		_auto_detect_resolution()
	apply_all()

func _auto_detect_resolution() -> void:
	## Pick the largest resolution in RESOLUTIONS that fits within the usable
	## screen area (excludes OS taskbars/docks so the window never overflows).
	var usable := DisplayServer.screen_get_usable_rect().size
	var best_idx := 0
	for i in range(RESOLUTIONS.size()):
		var r: Vector2i = RESOLUTIONS[i]
		if r.x <= usable.x and r.y <= usable.y:
			best_idx = i
	resolution_index = best_idx

# ---------------------------------------------------------------------------
# Audio bus setup
# ---------------------------------------------------------------------------

func _ensure_audio_buses() -> void:
	## Create Music and SFX buses if they don't exist yet.
	## Both route through Master so master_volume acts as a global ceiling.
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		var idx := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, "Music")
		AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var idx := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")

# ---------------------------------------------------------------------------
# Apply
# ---------------------------------------------------------------------------

func apply_all() -> void:
	apply_audio()
	apply_display()
	apply_ui_scale()

func apply_audio() -> void:
	## linear_to_db(0) = -inf (silence);  linear_to_db(1) = 0 dB (unity gain).
	var master_idx := AudioServer.get_bus_index("Master")
	var music_idx  := AudioServer.get_bus_index("Music")
	var sfx_idx    := AudioServer.get_bus_index("SFX")
	if master_idx != -1:
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(master_volume))
	if music_idx != -1:
		AudioServer.set_bus_volume_db(music_idx,  linear_to_db(music_volume))
	if sfx_idx != -1:
		AudioServer.set_bus_volume_db(sfx_idx,    linear_to_db(sfx_volume))

func apply_display() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var res: Vector2i = RESOLUTIONS[resolution_index]
		DisplayServer.window_set_size(res)
		# Re-centre the window inside the usable desktop area (excluding taskbar)
		var usable := DisplayServer.screen_get_usable_rect()
		DisplayServer.window_set_position(
			usable.position + Vector2i(
				(usable.size.x - res.x) / 2,
				(usable.size.y - res.y) / 2
			)
		)

func apply_ui_scale() -> void:
	## Shrinks or grows the virtual canvas so UI elements appear larger or smaller.
	##
	## Formula:  canvas_size = base_size / ui_scale
	##   ui_scale = 1.0  →  canvas 1280×960  (default)
	##   ui_scale = 2.0  →  canvas  640×480  → each pixel covers 2× screen space → bigger UI
	##   ui_scale = 0.5  →  canvas 2560×1920 → elements appear at half size → smaller UI
	var size := Vector2i(int(1280.0 / ui_scale), int(960.0 / ui_scale))
	get_tree().root.content_scale_size = size

# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio",   "master_volume",    master_volume)
	cfg.set_value("audio",   "music_volume",     music_volume)
	cfg.set_value("audio",   "sfx_volume",       sfx_volume)
	cfg.set_value("display", "fullscreen",       fullscreen)
	cfg.set_value("display", "resolution_index", resolution_index)
	cfg.set_value("display", "ui_scale",         ui_scale)
	cfg.save(SETTINGS_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return  # No settings file yet — the defaults declared above are used
	master_volume    = cfg.get_value("audio",   "master_volume",    master_volume)
	music_volume     = cfg.get_value("audio",   "music_volume",     music_volume)
	sfx_volume       = cfg.get_value("audio",   "sfx_volume",       sfx_volume)
	fullscreen       = cfg.get_value("display", "fullscreen",       fullscreen)
	resolution_index = cfg.get_value("display", "resolution_index", resolution_index)
	ui_scale         = cfg.get_value("display", "ui_scale",         ui_scale)
