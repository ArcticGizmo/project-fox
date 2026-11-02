class_name PauseMenu
extends CanvasLayer
## Pause menu (Start / Esc / P). Pauses the scene tree and frees the mouse.
## Navigable with D-pad/left stick + A/B, keyboard, or mouse.
## Restart and level changes are signals so the owning LevelRoot decides how.
## "Level" cycles the level selection; the restart button then loads it.
## "Debug..." opens a second page of testing shortcuts (DebugTools): max
## weapons, spawn any enemy, boss phases, invulnerability, rumble and volume.

signal restart_requested
signal level_requested(path: String)

var is_open: bool = false
## Scene path of the level this menu belongs to (set by LevelRoot).
var current_level_path: String = ""
## Index into LevelRoot.available_levels(); -1 = the current level.
var selected_level: int = -1
var levels: PackedStringArray = PackedStringArray()

var _resume: Button
var _boxes: Button
var _ai: Button
var _restart: Button
var _level: Button
var _gadgets: Button
var _quit: Button
var _mouse_mode_before: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _title: Label
var _main_box: VBoxContainer
var _debug_box: VBoxContainer
var _debug_button: Button
var _debug_back: Button
var _spawn_kind: Button
var _spawn_index: int = 0
var _boss2: Button
var _boss3: Button
var _god: Button
var _rumble: HSlider
var _volume: HSlider


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.1, 0.08, 0.95)
	style.border_color = Color(0.75, 0.6, 0.3)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override(&"panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	panel.add_child(box)

	var title := Label.new()
	_title = title
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 40)
	title.add_theme_color_override(&"font_color", Color(1, 0.85, 0.4))
	box.add_child(title)

	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override(&"separation", 12)
	box.add_child(_main_box)
	_resume = _button(_main_box, "Resume", close)
	_restart = _button(_main_box, "", _on_restart)
	_level = _button(_main_box, "", _on_cycle_level)
	_boxes = _button(_main_box, "", _on_toggle_boxes)
	_ai = _button(_main_box, "", _on_toggle_ai)
	_gadgets = _button(_main_box, "Unlock All Gadgets", _on_unlock_gadgets)
	_debug_button = _button(_main_box, "Debug...", show_debug_page)
	_quit = _button(_main_box, "Quit to Desktop", func() -> void: get_tree().quit())
	_build_debug_page(box)
	levels = LevelRoot.available_levels()
	selected_level = levels.find(current_level_path)
	DebugSettings.show_boxes_changed.connect(func(_on: bool) -> void: _refresh())
	DebugSettings.show_ai_changed.connect(func(_on: bool) -> void: _refresh())
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed(&"ui_cancel"):
		if is_debug_page():
			show_main_page()
		else:
			close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	Sfx.play(&"pause")
	visible = true
	_refresh()
	get_tree().paused = true
	_mouse_mode_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show_main_page()
	_resume.grab_focus()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = _mouse_mode_before


func _on_restart() -> void:
	close()
	var path := selected_level_path()
	if path == "" or path == current_level_path:
		restart_requested.emit()
	else:
		level_requested.emit(path)


## The chosen level's scene path, or "" when nothing else is selected.
func selected_level_path() -> String:
	return levels[selected_level] if selected_level >= 0 and selected_level < levels.size() else ""


func _on_cycle_level() -> void:
	if levels.is_empty():
		return
	selected_level = (selected_level + 1) % levels.size()
	_refresh()


func _on_unlock_gadgets() -> void:
	var p := get_tree().get_first_node_in_group(&"player") as Player
	if p != null:
		p.gadgets.unlock_all()
	_refresh()


func _on_toggle_boxes() -> void:
	DebugSettings.show_boxes = not DebugSettings.show_boxes


func _on_toggle_ai() -> void:
	DebugSettings.show_ai = not DebugSettings.show_ai


func _refresh() -> void:
	var path := selected_level_path()
	var same := path == "" or path == current_level_path
	_restart.text = "Restart Level" if same else "Load %s" % LevelRoot.level_name(path)
	var shown := path if path != "" else current_level_path
	_level.text = "Level: %s" % (LevelRoot.level_name(shown) if shown != "" else "-")
	var p := get_tree().get_first_node_in_group(&"player") as Player
	var all_unlocked := p != null and p.gadgets.unlocked.size() >= Gadgets.ALL.size()
	_gadgets.text = "Gadgets: all unlocked" if all_unlocked else "Unlock All Gadgets"
	_boxes.text = "Hitboxes: %s" % ("ON" if DebugSettings.show_boxes else "OFF")
	_ai.text = "AI Debug: %s" % ("ON" if DebugSettings.show_ai else "OFF")
	if _debug_box == null:
		return
	_spawn_kind.text = "Spawn: %s" % DebugTools.enemy_kinds()[_spawn_index]
	_god.text = "Invulnerable: %s" % ("ON" if p != null and p.god_mode else "OFF")
	var has_boss := DebugTools.boss(get_tree()) != null
	_boss2.disabled = not has_boss
	_boss3.disabled = not has_boss


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 52)
	b.add_theme_font_size_override(&"font_size", 24)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


# --- Debug page ---------------------------------------------------------------

func _build_debug_page(parent: Control) -> void:
	_debug_box = VBoxContainer.new()
	_debug_box.add_theme_constant_override(&"separation", 10)
	_debug_box.visible = false
	parent.add_child(_debug_box)
	var title := Label.new()
	title.text = "Debug"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 34)
	title.add_theme_color_override(&"font_color", Color(1, 0.85, 0.4))
	_debug_box.add_child(title)
	_debug_back = _button(_debug_box, "Back", show_main_page)
	_button(_debug_box, "Max All Weapons", func() -> void:
		var p := _player()
		if p != null:
			DebugTools.max_all_weapons(p))
	_button(_debug_box, "Current Weapon +1 Level", func() -> void:
		var p := _player()
		if p != null:
			p.debug_level_current_weapon())
	_spawn_kind = _button(_debug_box, "", func() -> void:
		var kinds := DebugTools.enemy_kinds()
		_spawn_index = (_spawn_index + 1) % kinds.size()
		_refresh())
	_button(_debug_box, "Spawn It", func() -> void:
		var p := _player()
		if p != null:
			DebugTools.spawn_enemy(p, DebugTools.enemy_kinds()[_spawn_index])
			close())
	_boss2 = _button(_debug_box, "Boss to Phase 2", func() -> void:
		if DebugTools.boss_to_phase(get_tree(), 2):
			close())
	_boss3 = _button(_debug_box, "Boss to Phase 3", func() -> void:
		if DebugTools.boss_to_phase(get_tree(), 3):
			close())
	_god = _button(_debug_box, "", func() -> void:
		var p := _player()
		if p != null:
			p.god_mode = not p.god_mode
		_refresh())
	_rumble = _slider(_debug_box, "Rumble", 0.0, 1.5, 0.05, GameFeel.rumble_strength, func(v: float) -> void:
		GameFeel.rumble_strength = v
		GameFeel.rumble(0.4 * v, 0.6 * v, 0.15))
	_volume = _slider(_debug_box, "Sound (dB)", -30.0, 6.0, 1.0, Sfx.volume_db, func(v: float) -> void:
		Sfx.volume_db = v
		Sfx.play(&"wheel_select"))


func show_debug_page() -> void:
	_main_box.visible = false
	_title.visible = false
	_debug_box.visible = true
	_refresh()
	_debug_back.grab_focus()


func show_main_page() -> void:
	_debug_box.visible = false
	_main_box.visible = true
	_title.visible = true
	_debug_button.grab_focus()


func is_debug_page() -> bool:
	return _debug_box.visible


func _player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


## A labelled slider row (left/right on the D-pad or stick adjusts it).
func _slider(parent: Control, text: String, lo: float, hi: float, step: float, value: float, changed: Callable) -> HSlider:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(130, 0)
	label.add_theme_font_size_override(&"font_size", 22)
	row.add_child(label)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(210, 40)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(changed)
	row.add_child(s)
	parent.add_child(row)
	return s
