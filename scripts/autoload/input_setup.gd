extends Node
## Builds the input map in code so every binding lives in one reviewable file.
## Controller is the primary scheme; every action also gets a keyboard/mouse
## binding so KB+M support is never designed out.

const STICK_DEADZONE := 0.2
const TRIGGER_DEADZONE := 0.3


func _enter_tree() -> void:
	# Analog movement and camera.
	_add_axis(&"move_left", JOY_AXIS_LEFT_X, -1.0, [KEY_A])
	_add_axis(&"move_right", JOY_AXIS_LEFT_X, 1.0, [KEY_D])
	_add_axis(&"move_forward", JOY_AXIS_LEFT_Y, -1.0, [KEY_W])
	_add_axis(&"move_back", JOY_AXIS_LEFT_Y, 1.0, [KEY_S])
	_add_axis(&"look_left", JOY_AXIS_RIGHT_X, -1.0, [KEY_LEFT])
	_add_axis(&"look_right", JOY_AXIS_RIGHT_X, 1.0, [KEY_RIGHT])
	_add_axis(&"look_up", JOY_AXIS_RIGHT_Y, -1.0, [KEY_UP])
	_add_axis(&"look_down", JOY_AXIS_RIGHT_Y, 1.0, [KEY_DOWN])

	# Triggers.
	_add_axis(&"fire", JOY_AXIS_TRIGGER_RIGHT, 1.0, [], [MOUSE_BUTTON_LEFT], TRIGGER_DEADZONE)
	_add_axis(&"strafe", JOY_AXIS_TRIGGER_LEFT, 1.0, [], [MOUSE_BUTTON_RIGHT], TRIGGER_DEADZONE)

	# Buttons.
	_add_button(&"jump", [JOY_BUTTON_A], [KEY_SPACE])
	_add_button(&"dodge", [JOY_BUTTON_B], [KEY_SHIFT])
	_add_button(&"melee", [JOY_BUTTON_X], [KEY_F], [MOUSE_BUTTON_XBUTTON1])
	_add_button(&"weapon_next", [JOY_BUTTON_RIGHT_SHOULDER], [KEY_E])
	_add_button(&"weapon_prev", [JOY_BUTTON_LEFT_SHOULDER], [KEY_Q])
	_add_button(&"weapon_wheel", [JOY_BUTTON_Y], [KEY_TAB])
	for i: int in 8:
		_add_button(StringName("weapon_slot_%d" % (i + 1)), [], [KEY_1 + i])
	_add_button(&"pause", [JOY_BUTTON_START], [KEY_ESCAPE, KEY_P])

	# Debug.
	_add_button(&"debug_toggle_boxes", [JOY_BUTTON_BACK], [KEY_F1])
	# Controllers reach the AI debug view through the pause menu.
	_add_button(&"debug_toggle_ai", [], [KEY_F4])
	_add_button(&"debug_give_xp", [JOY_BUTTON_DPAD_UP], [KEY_F2])
	_add_button(&"debug_next_wave", [JOY_BUTTON_DPAD_DOWN], [KEY_F3])

	_extend_ui_navigation()


func _add_axis(action: StringName, axis: JoyAxis, direction: float, keys: Array[int] = [], mouse_buttons: Array[int] = [], deadzone: float = STICK_DEADZONE) -> void:
	_ensure(action, deadzone)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = direction
	InputMap.action_add_event(action, ev)
	_add_keys(action, keys, mouse_buttons)


func _add_button(action: StringName, buttons: Array[int], keys: Array[int] = [], mouse_buttons: Array[int] = []) -> void:
	_ensure(action, 0.5)
	for b: int in buttons:
		var ev := InputEventJoypadButton.new()
		ev.button_index = b as JoyButton
		InputMap.action_add_event(action, ev)
	_add_keys(action, keys, mouse_buttons)


func _add_keys(action: StringName, keys: Array[int], mouse_buttons: Array[int]) -> void:
	for k: int in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k as Key
		InputMap.action_add_event(action, ev)
	for b: int in mouse_buttons:
		var mb := InputEventMouseButton.new()
		mb.button_index = b as MouseButton
		InputMap.action_add_event(action, mb)


func _ensure(action: StringName, deadzone: float) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action, deadzone)
	InputMap.action_set_deadzone(action, deadzone)


## Make sure menus work with a controller: D-pad and left stick to move,
## A to accept, B to go back. Adds to Godot's defaults rather than replacing.
func _extend_ui_navigation() -> void:
	_ensure_joy_axis(&"ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_ensure_joy_axis(&"ui_down", JOY_AXIS_LEFT_Y, 1.0)
	_ensure_joy_axis(&"ui_left", JOY_AXIS_LEFT_X, -1.0)
	_ensure_joy_axis(&"ui_right", JOY_AXIS_LEFT_X, 1.0)
	_ensure_joy_button(&"ui_up", JOY_BUTTON_DPAD_UP)
	_ensure_joy_button(&"ui_down", JOY_BUTTON_DPAD_DOWN)
	_ensure_joy_button(&"ui_left", JOY_BUTTON_DPAD_LEFT)
	_ensure_joy_button(&"ui_right", JOY_BUTTON_DPAD_RIGHT)
	_ensure_joy_button(&"ui_accept", JOY_BUTTON_A)
	_ensure_joy_button(&"ui_cancel", JOY_BUTTON_B)


func _ensure_joy_axis(action: StringName, axis: JoyAxis, direction: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = direction
	if not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)


func _ensure_joy_button(action: StringName, button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	if not InputMap.action_has_event(action, ev):
		InputMap.action_add_event(action, ev)
