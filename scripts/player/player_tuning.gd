class_name PlayerTuning
extends Resource
## Every "feel" number for the player and camera lives here.
## Edit res://data/player_tuning.tres in the inspector to tweak without code.

@export_group("Ground")
@export var run_speed: float = 8.5
@export var ground_acceleration: float = 70.0
@export var ground_deceleration: float = 90.0
@export var strafe_speed_multiplier: float = 0.85
## How fast the fox turns to face its movement direction.
@export var turn_speed_deg: float = 900.0
## Faster turn used when snapping to the aim direction while firing.
@export var fire_turn_speed_deg: float = 1800.0

@export_group("Air")
@export var gravity: float = 30.0
@export var fall_gravity_multiplier: float = 1.6
## Extra gravity while rising with jump released: gives variable jump height.
@export var jump_release_gravity_multiplier: float = 2.5
@export var max_fall_speed: float = 30.0
## Apex height in metres when jump is held.
@export var jump_height: float = 2.2
@export var double_jump_height: float = 1.6
@export var air_acceleration: float = 35.0
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12

@export_group("Dodge")
@export var dodge_speed: float = 17.0
@export var dodge_duration: float = 0.22
@export var dodge_iframes: float = 0.2
@export var dodge_cooldown: float = 0.35

@export_group("Combat")
@export var max_health: float = 100.0
@export var hurt_iframes: float = 0.8
@export var hurt_knockback_scale: float = 1.0
## Seconds the fox keeps facing the aim direction after releasing fire.
@export var fire_facing_time: float = 0.4
@export var aim_assist_angle_deg: float = 9.0
@export var aim_max_range: float = 60.0

@export_group("Camera")
@export var camera_distance: float = 5.5
@export var camera_height: float = 1.7
## Lifts the camera above the orbit pivot so the reticle sits above the fox.
@export var camera_vertical_offset: float = 1.1
@export var camera_fov: float = 70.0
@export var camera_follow_sharpness: float = 14.0
@export var camera_vertical_sharpness: float = 6.0
@export var look_speed_yaw_deg: float = 220.0
@export var look_speed_pitch_deg: float = 130.0
## >1 gives finer control near stick centre.
@export var look_response_exponent: float = 1.8
## Degrees per pixel of mouse movement.
@export var mouse_sensitivity: float = 0.15
@export var invert_y: bool = false
@export var pitch_min_deg: float = -60.0
@export var pitch_max_deg: float = 35.0
@export var default_pitch_deg: float = -15.0
@export var shake_decay: float = 5.0
@export var max_shake_offset: float = 0.35


func jump_velocity() -> float:
	return sqrt(2.0 * gravity * jump_height)


func double_jump_velocity() -> float:
	return sqrt(2.0 * gravity * double_jump_height)
