## HUD.gd
## The entire in-game UI is built programmatically in _ready().
## This avoids having to manually write complex .tscn layout nodes,
## and keeps all UI logic in one readable script.
##
## Layout:
##   - Top bar (full width, 50 px): Gold / Lives / Wave labels
##   - Right panel (200 px wide): Tower purchase buttons + Start Wave button
##   - Upgrade panel (right side, appears when a tower is selected):
##       target mode dropdown, upgrade button, sell button
##
## Signals emitted to Game.gd:
##   tower_type_selected(type: String)  — player wants to place a tower
##   wave_start_requested()             — player pressed Start Wave

extends CanvasLayer

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal tower_type_selected(type: String)
signal wave_start_requested()

# ---------------------------------------------------------------------------
# Node references — assigned in _build_ui()
# ---------------------------------------------------------------------------
var _gold_label:          Label
var _lives_label:         Label
var _wave_label:          Label
var _start_wave_btn:      Button
var _upgrade_panel:       Panel
var _upgrade_level_label: Label
var _upgrade_btn:         Button
var _sell_btn:            Button
var _target_mode_btn:     OptionButton
var _selected_tower_name: Label

## Currently selected tower (null if none)
var _selected_tower = null  # Type: Tower (can't use class_name due to load order)

## Save-game overlay panel and its slot info labels
var _save_panel:        Panel
var _save_slot_labels:  Array[Label] = []

# Layout constants — pixel values in the 1280×960 virtual canvas;
# the stretch/canvas_items mode scales them to any window size automatically.
const PANEL_WIDTH:  int = 200
const TOP_BAR_H:    int = 50

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_ui()
	# Connect to GameManager signals so labels stay in sync
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.wave_changed.connect(_on_wave_changed)
	# Push current values immediately (in case game already started)
	_on_gold_changed(GameManager.gold)
	_on_lives_changed(GameManager.lives)
	_on_wave_changed(GameManager.current_wave)

# ---------------------------------------------------------------------------
# UI construction
# ---------------------------------------------------------------------------

func _canvas_size() -> Vector2:
	var cs := get_tree().root.content_scale_size
	if cs.x > 0 and cs.y > 0:
		return Vector2(cs)
	return get_viewport().get_visible_rect().size

func _build_ui() -> void:
	## Build every UI element in code so nothing depends on a .tscn layout.
	var cs := _canvas_size()

	# ---- Top bar ----
	var top_bar := Panel.new()
	top_bar.position = Vector2.ZERO
	top_bar.size     = Vector2(cs.x, TOP_BAR_H)
	add_child(top_bar)

	var top_hbox := HBoxContainer.new()
	top_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	top_hbox.add_theme_constant_override("separation", 40)
	top_bar.add_child(top_hbox)

	_gold_label  = _make_label("Gold: 150",  Color(1.0, 0.85, 0.0))
	_lives_label = _make_label("Lives: 20",  Color(0.2, 1.0, 0.4))
	_wave_label  = _make_label("Wave: 0",    Color(0.7, 0.85, 1.0))
	top_hbox.add_child(_gold_label)
	top_hbox.add_child(_lives_label)
	top_hbox.add_child(_wave_label)

	# ---- Right panel (tower shop + start wave) ----
	var right_panel := Panel.new()
	right_panel.position = Vector2(cs.x - PANEL_WIDTH, TOP_BAR_H)
	right_panel.size     = Vector2(PANEL_WIDTH, 500)
	add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	right_vbox.add_theme_constant_override("separation", 6)
	right_panel.add_child(right_vbox)

	var shop_title := _make_label("-- Place Tower --", Color.WHITE)
	shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_vbox.add_child(shop_title)

	# Tower purchase buttons — emit signal with the tower type string
	_add_tower_button(right_vbox, "Basic  (50g)",  "basic")
	_add_tower_button(right_vbox, "Slow   (75g)",  "slow")
	_add_tower_button(right_vbox, "Sniper (100g)", "sniper")
	_add_tower_button(right_vbox, "Splash (125g)", "splash")

	right_vbox.add_child(HSeparator.new())

	_start_wave_btn = Button.new()
	_start_wave_btn.text = "Start Wave 1"
	_start_wave_btn.pressed.connect(_on_start_wave_pressed)
	right_vbox.add_child(_start_wave_btn)

	right_vbox.add_child(HSeparator.new())

	var save_btn := Button.new()
	save_btn.text = "Save Game"
	save_btn.pressed.connect(_on_save_requested)
	right_vbox.add_child(save_btn)

	# ---- Save slot overlay (hidden until Save Game is pressed) ----
	_build_save_panel()

	# ---- Upgrade / sell panel (shown when a tower is selected) ----
	_upgrade_panel = Panel.new()
	_upgrade_panel.position = Vector2(cs.x - PANEL_WIDTH, TOP_BAR_H + 425)
	_upgrade_panel.size     = Vector2(PANEL_WIDTH, 265)
	_upgrade_panel.visible  = false
	add_child(_upgrade_panel)

	var up_vbox := VBoxContainer.new()
	up_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	up_vbox.add_theme_constant_override("separation", 6)
	_upgrade_panel.add_child(up_vbox)

	var sel_title := _make_label("-- Selected --", Color.WHITE)
	sel_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	up_vbox.add_child(sel_title)

	_selected_tower_name = _make_label("", Color(0.9, 0.9, 0.6))
	_selected_tower_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	up_vbox.add_child(_selected_tower_name)

	_upgrade_level_label = _make_label("Level: 0/3", Color.WHITE)
	up_vbox.add_child(_upgrade_level_label)

	# Targeting mode selector
	var target_label := _make_label("Target:", Color(0.8, 0.8, 0.8))
	up_vbox.add_child(target_label)

	_target_mode_btn = OptionButton.new()
	_target_mode_btn.add_item("First",    0)
	_target_mode_btn.add_item("Last",     1)
	_target_mode_btn.add_item("Strongest",2)
	_target_mode_btn.add_item("Weakest",  3)
	_target_mode_btn.add_item("Closest",  4)
	_target_mode_btn.item_selected.connect(_on_target_mode_changed)
	up_vbox.add_child(_target_mode_btn)

	up_vbox.add_child(HSeparator.new())

	_upgrade_btn = Button.new()
	_upgrade_btn.pressed.connect(_on_upgrade_pressed)
	up_vbox.add_child(_upgrade_btn)

	_sell_btn = Button.new()
	_sell_btn.pressed.connect(_on_sell_pressed)
	up_vbox.add_child(_sell_btn)

# ---------------------------------------------------------------------------
# Save panel — centered overlay shown when "Save Game" is pressed
# ---------------------------------------------------------------------------

func _build_save_panel() -> void:
	var cs := _canvas_size()
	_save_panel = Panel.new()
	_save_panel.position = Vector2(cs.x * 0.5 - 200, cs.y * 0.5 - 130)
	_save_panel.size     = Vector2(400, 260)
	_save_panel.visible  = false
	add_child(_save_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	vbox.add_theme_constant_override("separation", 8)
	_save_panel.add_child(vbox)

	var title := _make_label("Save Game", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	for slot in range(SaveManager.SAVE_SLOTS):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var info := _make_label("Slot %d: Empty" % (slot + 1), Color(0.75, 0.75, 0.75))
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		_save_slot_labels.append(info)

		var btn := Button.new()
		btn.text = "Save"
		btn.custom_minimum_size = Vector2(60, 0)
		btn.pressed.connect(func(): _on_save_to_slot(slot))
		row.add_child(btn)

		vbox.add_child(row)

	vbox.add_child(HSeparator.new())

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(func(): _save_panel.visible = false)
	vbox.add_child(cancel)

func _on_save_requested() -> void:
	## Refresh slot info labels and show the save panel.
	for slot in range(SaveManager.SAVE_SLOTS):
		var info := SaveManager.get_save_info(slot)
		if info.is_empty():
			_save_slot_labels[slot].text = "Slot %d: Empty" % (slot + 1)
		else:
			_save_slot_labels[slot].text = "Slot %d: Wave %d" % [slot + 1, info["wave"]]
	_save_panel.visible = true

func _on_save_to_slot(slot: int) -> void:
	SaveManager.save_game(slot)
	_save_panel.visible = false

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_label(text: String, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text                = text
	lbl.add_theme_color_override("font_color", color)
	return lbl

func _add_tower_button(parent: VBoxContainer, label: String, type: String) -> void:
	var btn := Button.new()
	btn.text = label
	# Capture 'type' by value with a lambda so each button emits the right type
	btn.pressed.connect(func(): tower_type_selected.emit(type))
	parent.add_child(btn)

# ---------------------------------------------------------------------------
# Public API called by Game.gd
# ---------------------------------------------------------------------------

## Show the upgrade/sell panel for the given tower.
func show_tower_info(tower) -> void:
	_selected_tower = tower
	_upgrade_panel.visible = true
	_selected_tower_name.text = tower.get_script().resource_path.get_file().get_basename()
	_refresh_upgrade_panel()

## Hide the upgrade/sell panel.
func hide_tower_info() -> void:
	_selected_tower = null
	_upgrade_panel.visible = false

## Called by WaveManager when a wave ends so the button reactivates.
func on_wave_completed(next_wave_number: int) -> void:
	_start_wave_btn.disabled = false
	_start_wave_btn.text = "Start Wave %d" % next_wave_number

## Called when all waves are finished.
func on_all_waves_done() -> void:
	_start_wave_btn.disabled = true
	_start_wave_btn.text = "All Waves Done!"

# ---------------------------------------------------------------------------
# Internal refresh
# ---------------------------------------------------------------------------

func _refresh_upgrade_panel() -> void:
	if _selected_tower == null:
		return
	var t = _selected_tower
	var can_upgrade: bool = t.upgrade_level < t.max_upgrades
	var can_afford: bool  = GameManager.gold >= t.upgrade_cost

	_upgrade_level_label.text = "Level: %d / 3" % (t.upgrade_level + 1)

	if can_upgrade:
		_upgrade_btn.text     = "-> Lv.%d  (%dg)" % [t.upgrade_level + 2, t.upgrade_cost]
		_upgrade_btn.disabled = not can_afford
	else:
		_upgrade_btn.text     = "Max Level"
		_upgrade_btn.disabled = true

	_sell_btn.text = "Sell (%dg)" % t.sell_value

	# Sync dropdown to current target mode
	_target_mode_btn.selected = t.target_mode as int

# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_gold_changed(amount: int) -> void:
	_gold_label.text = "Gold: %d" % amount
	# Refresh upgrade button in case affordability changed
	_refresh_upgrade_panel()

func _on_lives_changed(amount: int) -> void:
	_lives_label.text = "Lives: %d" % amount

func _on_wave_changed(wave: int) -> void:
	_wave_label.text = "Wave: %d" % wave

func _on_start_wave_pressed() -> void:
	_start_wave_btn.disabled = true
	wave_start_requested.emit()

func _on_upgrade_pressed() -> void:
	if _selected_tower != null:
		_selected_tower.upgrade()
		_refresh_upgrade_panel()

func _on_sell_pressed() -> void:
	if _selected_tower != null:
		_selected_tower.sell()
		hide_tower_info()

func _on_target_mode_changed(index: int) -> void:
	if _selected_tower != null:
		_selected_tower.set_target_mode(index as Tower.TargetMode)
