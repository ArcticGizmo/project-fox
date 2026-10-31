class_name PlayerInputState
extends RefCounted
## Device-agnostic snapshot of player intent for one physics frame.
## The player only ever reads this, never the Input singleton, so controller,
## keyboard/mouse and scripted test input are interchangeable.

## Left stick / WASD. Godot convention: y is negative when pushing forward.
var move: Vector2 = Vector2.ZERO
## Right stick, -1..1 per axis, scaled by look speed over time.
var look: Vector2 = Vector2.ZERO
## Mouse delta in pixels since the last poll, applied directly.
var mouse_look: Vector2 = Vector2.ZERO
var jump_pressed: bool = false
var jump_held: bool = false
var dodge_pressed: bool = false
var melee_pressed: bool = false
var fire_held: bool = false
var strafe_held: bool = false
var weapon_next: bool = false
var weapon_prev: bool = false
## 0-based slot requested this frame, or -1.
var weapon_slot: int = -1


func copy_from(other: PlayerInputState) -> void:
	move = other.move
	look = other.look
	mouse_look = other.mouse_look
	jump_pressed = other.jump_pressed
	jump_held = other.jump_held
	dodge_pressed = other.dodge_pressed
	melee_pressed = other.melee_pressed
	fire_held = other.fire_held
	strafe_held = other.strafe_held
	weapon_next = other.weapon_next
	weapon_prev = other.weapon_prev
	weapon_slot = other.weapon_slot
