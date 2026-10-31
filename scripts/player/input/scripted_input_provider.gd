class_name ScriptedInputProvider
extends InputProvider
## Input for tests (and later, demo playback). Set fields on `next`;
## one-shot presses are cleared after a single poll, held values persist.

var next: PlayerInputState = PlayerInputState.new()


func poll(state: PlayerInputState, _delta: float) -> void:
	state.copy_from(next)
	next.jump_pressed = false
	next.dodge_pressed = false
	next.melee_pressed = false
	next.weapon_next = false
	next.weapon_prev = false
	next.weapon_slot = -1
	next.mouse_look = Vector2.ZERO
