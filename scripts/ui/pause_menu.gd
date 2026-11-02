class_name PauseMenu
extends CanvasLayer
## Pause menu (Start / Esc / P). Pauses the scene tree and frees the mouse.
## Navigable with D-pad/left stick + A/B, keyboard, or mouse.
## Restart and level changes are signals so the owning LevelRoot decides how.
## "Level" cycles the level selection; the restart button then loads it.

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
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 40)
	title.add_theme_color_override(&"font_color", Color(1, 0.85, 0.4))
	box.add_child(title)

	_resume = _button(box, "Resume", close)
	_restart = _button(box, "", _on_restart)
	_level = _button(box, "", _on_cycle_level)
	_boxes = _button(box, "", _on_toggle_boxes)
	_ai = _button(box, "", _on_toggle_ai)
	_gadgets = _button(box, "Unlock All Gadgets", _on_unlock_gadgets)
	_quit = _button(box, "Quit to Desktop", func() -> void: get_tree().quit())
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


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(340, 52)
	b.add_theme_font_size_override(&"font_size", 24)
	b.pressed.connect(action)
	parent.add_child(b)
	return b
