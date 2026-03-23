## MainMenu.gd
## The game's start screen, shown when the application launches.
## All UI is built programmatically to match the in-game HUD aesthetic.
##
## Three sub-panels are swapped in/out based on what the player clicks:
##   Main    — New Game / Load Game / Options / Quit
##   Load    — Three save-slot rows; each shows save info + Load + Delete buttons
##   Options — Master/Music/SFX sliders, resolution picker, fullscreen toggle, UI scale

extends CanvasLayer

# ---------------------------------------------------------------------------
# Panel node references — populated during the _build_*() calls in _ready()
# ---------------------------------------------------------------------------
var _main_panel:    Control = null
var _load_panel:    Control = null
var _options_panel: Control = null

# Options controls — kept so _sync_options_to_settings() can push values back in
var _master_slider:  HSlider      = null
var _music_slider:   HSlider      = null
var _sfx_slider:     HSlider      = null
var _res_option:     OptionButton = null
var _fullscreen_btn: CheckButton  = null
var _scale_slider:   HSlider      = null

# Load panel slot labels — one per slot, updated each time the panel opens
var _slot_info_labels: Array[Label] = []

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_build_background()
	_build_main_panel()
	_build_load_panel()
	_build_options_panel()
	_show_main()

# ---------------------------------------------------------------------------
# Background + title text
# ---------------------------------------------------------------------------

func _build_background() -> void:
	var cs := _canvas_size()

	var bg := ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size     = cs
	bg.color    = Color(0.08, 0.11, 0.08)
	add_child(bg)

	var title := Label.new()
	title.text = "TOWER DEFENSE"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.25, 0.85, 0.25))
	title.position = Vector2(0, 80)
	title.size     = Vector2(cs.x, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var sub := Label.new()
	sub.text = "Build. Defend. Survive."
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.50, 0.65, 0.50))
	sub.position = Vector2(0, 160)
	sub.size     = Vector2(cs.x, 35)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

# ---------------------------------------------------------------------------
# Panel visibility helpers
# ---------------------------------------------------------------------------

func _show_main() -> void:
	_main_panel.visible    = true
	_load_panel.visible    = false
	_options_panel.visible = false

func _show_load() -> void:
	_main_panel.visible    = false
	_load_panel.visible    = true
	_options_panel.visible = false
	_refresh_load_panel()   # Fetch fresh save info every time the panel opens

func _show_options() -> void:
	_main_panel.visible    = false
	_load_panel.visible    = false
	_options_panel.visible = true
	_sync_options_to_settings()   # Make sure controls reflect any external changes

# ---------------------------------------------------------------------------
# Main panel — four menu buttons
# ---------------------------------------------------------------------------

func _build_main_panel() -> void:
	_main_panel = _centered_panel(300, 290, 40)
	add_child(_main_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	vbox.add_theme_constant_override("separation", 12)
	_main_panel.add_child(vbox)

	_menu_btn(vbox, "New Game",  _on_new_game)
	_menu_btn(vbox, "Load Game", _on_load_game)
	_menu_btn(vbox, "Options",   _on_options)
	_menu_btn(vbox, "Quit Game", _on_quit)

func _menu_btn(parent: VBoxContainer, text: String, cb: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 52)
	btn.pressed.connect(cb)
	parent.add_child(btn)

# ---------------------------------------------------------------------------
# Load panel — 3 save-slot rows
# ---------------------------------------------------------------------------

func _build_load_panel() -> void:
	_load_panel = _centered_panel(480, 320, 40)
	add_child(_load_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	vbox.add_theme_constant_override("separation", 8)
	_load_panel.add_child(vbox)

	vbox.add_child(_section_label("Load Game"))
	vbox.add_child(HSeparator.new())

	# One row per slot: info label + Load button + Delete button
	for slot in range(SaveManager.SAVE_SLOTS):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 48)

		var info := Label.new()
		info.text = "Slot %d:  Empty" % (slot + 1)
		info.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		_slot_info_labels.append(info)

		var load_btn := Button.new()
		load_btn.text = "Load"
		load_btn.custom_minimum_size = Vector2(72, 0)
		load_btn.pressed.connect(func(): _on_load_slot(slot))
		row.add_child(load_btn)

		var del_btn := Button.new()
		del_btn.text = "Delete"
		del_btn.custom_minimum_size = Vector2(72, 0)
		del_btn.pressed.connect(func(): _on_delete_slot(slot))
		row.add_child(del_btn)

		vbox.add_child(row)

	vbox.add_child(HSeparator.new())

	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(_show_main)
	vbox.add_child(back)

func _refresh_load_panel() -> void:
	## Update every slot label with current save data from disk.
	for slot in range(SaveManager.SAVE_SLOTS):
		var info := SaveManager.get_save_info(slot)
		if info.is_empty():
			_slot_info_labels[slot].text = "Slot %d:  Empty" % (slot + 1)
		else:
			_slot_info_labels[slot].text = (
				"Slot %d:  Wave %d  |  Score %d\n%s" % [
					slot + 1, info["wave"], info["score"], info["timestamp"]
				]
			)

# ---------------------------------------------------------------------------
# Options panel — audio / display / UI scale
# ---------------------------------------------------------------------------

func _build_options_panel() -> void:
	_options_panel = _centered_panel(500, 510, 30)
	add_child(_options_panel)

	# ScrollContainer so the panel content stays accessible at any UI scale
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_options_panel.add_child(scroll)

	# MarginContainer gives consistent padding around all content
	var outer := MarginContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("margin_left",   16)
	outer.add_theme_constant_override("margin_right",  16)
	outer.add_theme_constant_override("margin_top",    12)
	outer.add_theme_constant_override("margin_bottom", 12)
	# Explicit minimum width prevents the ScrollContainer from collapsing the content
	outer.custom_minimum_size = Vector2(468, 0)
	scroll.add_child(outer)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	outer.add_child(vbox)

	# ---- Header ----
	vbox.add_child(_section_label("Options", 22))
	vbox.add_child(HSeparator.new())

	# ---- Audio ----
	vbox.add_child(_section_label("Audio", 15, Color(0.65, 0.85, 1.0)))

	_master_slider = _slider_row(vbox, "Master", 0.0, 1.0, SettingsManager.master_volume,
		func(v: float):
			SettingsManager.master_volume = v
			SettingsManager.apply_audio()
	)
	_music_slider = _slider_row(vbox, "Music", 0.0, 1.0, SettingsManager.music_volume,
		func(v: float):
			SettingsManager.music_volume = v
			SettingsManager.apply_audio()
	)
	_sfx_slider = _slider_row(vbox, "SFX", 0.0, 1.0, SettingsManager.sfx_volume,
		func(v: float):
			SettingsManager.sfx_volume = v
			SettingsManager.apply_audio()
	)

	vbox.add_child(HSeparator.new())

	# ---- Display ----
	vbox.add_child(_section_label("Display", 15, Color(1.0, 0.85, 0.55)))

	# Resolution dropdown
	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 8)
	var res_lbl := Label.new()
	res_lbl.text = "Resolution"
	res_lbl.custom_minimum_size = Vector2(120, 0)
	res_row.add_child(res_lbl)
	_res_option = OptionButton.new()
	_res_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for lbl in SettingsManager.RESOLUTION_LABELS:
		_res_option.add_item(lbl)
	_res_option.selected = SettingsManager.resolution_index
	_res_option.item_selected.connect(func(idx: int):
		SettingsManager.resolution_index = idx
		SettingsManager.apply_display()
		SettingsManager.save_settings()
	)
	res_row.add_child(_res_option)
	vbox.add_child(res_row)

	# Fullscreen toggle
	var fs_row := HBoxContainer.new()
	fs_row.add_theme_constant_override("separation", 8)
	var fs_lbl := Label.new()
	fs_lbl.text = "Fullscreen"
	fs_lbl.custom_minimum_size = Vector2(120, 0)
	fs_row.add_child(fs_lbl)
	_fullscreen_btn = CheckButton.new()
	_fullscreen_btn.button_pressed = SettingsManager.fullscreen
	_fullscreen_btn.toggled.connect(func(on: bool):
		SettingsManager.fullscreen = on
		SettingsManager.apply_display()
		SettingsManager.save_settings()
	)
	fs_row.add_child(_fullscreen_btn)
	vbox.add_child(fs_row)

	vbox.add_child(HSeparator.new())

	# ---- UI Scale ----
	vbox.add_child(_section_label("Interface", 15, Color(0.75, 1.0, 0.75)))

	_scale_slider = _slider_row(vbox, "UI Scale", 0.5, SettingsManager.MAX_UI_SCALE, SettingsManager.ui_scale,
		func(v: float):
			SettingsManager.ui_scale = v
			SettingsManager.apply_ui_scale()
	)
	_scale_slider.step = 0.25   # Snap to quarter-unit increments

	var hint := Label.new()
	hint.text = "0.5 = smaller UI      1.0 = default (max)"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.50, 0.50, 0.50))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	vbox.add_child(HSeparator.new())

	# Back — all settings applied live; just save and close
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func():
		SettingsManager.save_settings()
		_show_main()
	)
	vbox.add_child(back)

func _sync_options_to_settings() -> void:
	## Push SettingsManager values into the UI controls each time Options opens.
	## Keeps the panel in sync if settings were changed elsewhere.
	_master_slider.value           = SettingsManager.master_volume
	_music_slider.value            = SettingsManager.music_volume
	_sfx_slider.value              = SettingsManager.sfx_volume
	_res_option.selected           = SettingsManager.resolution_index
	_fullscreen_btn.button_pressed = SettingsManager.fullscreen
	_scale_slider.value            = SettingsManager.ui_scale

# ---------------------------------------------------------------------------
# Shared UI helpers
# ---------------------------------------------------------------------------

func _canvas_size() -> Vector2:
	## Virtual canvas dimensions — set by SettingsManager before this scene loads.
	var cs := get_tree().root.content_scale_size
	if cs.x > 0 and cs.y > 0:
		return Vector2(cs)
	return get_viewport().get_visible_rect().size

func _centered_panel(w: int, h: int, y_offset: int) -> Panel:
	## Returns a Panel explicitly positioned at the canvas centre + y_offset.
	## Uses content_scale_size directly instead of anchor resolution so the
	## position is correct even though CanvasLayer has no queryable parent size.
	var cs := _canvas_size()
	var p  := Panel.new()
	p.position = Vector2((cs.x - w) * 0.5, (cs.y - h) * 0.5 + y_offset)
	p.size     = Vector2(w, h)
	return p

func _section_label(text: String, size: int = 20,
		color: Color = Color.WHITE) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl

func _slider_row(parent: VBoxContainer, label_text: String,
		min_v: float, max_v: float, initial: float,
		on_change: Callable) -> HSlider:
	## Build a  [Label] [======Slider======] [0.00]  row.
	## on_change is called with the new value on every slider move.
	## Settings are saved when the player releases the drag handle.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(110, 0)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.value     = initial
	slider.step      = 0.01
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % initial
	val_lbl.custom_minimum_size = Vector2(42, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)

	# Live update: refresh the value label and call on_change every frame the slider moves
	slider.value_changed.connect(func(v: float):
		val_lbl.text = "%.2f" % v
		on_change.call(v)
	)
	# Auto-save once the player releases the handle (avoids many writes during drag)
	slider.drag_ended.connect(func(_changed: bool):
		SettingsManager.save_settings()
	)

	parent.add_child(row)
	return slider

# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

func _on_new_game() -> void:
	## No pending_load set → Game._ready() calls GameManager.start_game() for a fresh run.
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_load_game() -> void:
	_show_load()

func _on_options() -> void:
	_show_options()

func _on_quit() -> void:
	get_tree().quit()

func _on_load_slot(slot: int) -> void:
	## SaveManager stores the save dict in pending_load.
	## Game._ready() detects it and calls _restore_from_save().
	if SaveManager.load_game(slot):
		get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_delete_slot(slot: int) -> void:
	SaveManager.delete_save(slot)
	_refresh_load_panel()
