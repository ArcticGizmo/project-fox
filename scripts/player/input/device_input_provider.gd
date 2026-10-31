class_name DeviceInputProvider
extends InputProvider
## Reads the real input map (controller + keyboard/mouse, see InputSetup).

var _mouse_delta: Vector2 = Vector2.ZERO


func add_mouse_motion(relative: Vector2) -> void:
	_mouse_delta += relative


func poll(state: PlayerInputState, _delta: float) -> void:
	state.move = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	state.look = Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	state.mouse_look = _mouse_delta
	_mouse_delta = Vector2.ZERO
	state.jump_pressed = Input.is_action_just_pressed(&"jump")
	state.jump_held = Input.is_action_pressed(&"jump")
	state.dodge_pressed = Input.is_action_just_pressed(&"dodge")
	state.fire_held = Input.is_action_pressed(&"fire")
	state.strafe_held = Input.is_action_pressed(&"strafe")
	state.weapon_next = Input.is_action_just_pressed(&"weapon_next")
	state.weapon_prev = Input.is_action_just_pressed(&"weapon_prev")
	state.weapon_slot = -1
	for i: int in 3:
		if Input.is_action_just_pressed(StringName("weapon_slot_%d" % (i + 1))):
			state.weapon_slot = i
