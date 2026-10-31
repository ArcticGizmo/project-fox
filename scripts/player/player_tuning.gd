class_name PlayerTuning
extends Resource
## Every "feel" number for the player and camera lives here.
## Edit res://data/player_tuning.tres in the inspector to tweak without code.

@export_group("Ground")
@export var run_speed: float = 8.5
@export var ground_acceleration: float = 70.0
@export var ground_deceleration: float = 90.0
## 1 = full run speed (matching R&C feel until we know better).
@export var strafe_speed_multiplier: float = 1.0
## Extra multiplier when moving directly backwards while strafing (1 = none).
@export var strafe_backpedal_multiplier: float = 1.0
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
## How quickly distance/FOV/shoulder blend between normal, strafe and zoom views.
@export var camera_mode_sharpness: float = 12.0
@export var shake_decay: float = 5.0
@export var max_shake_offset: float = 0.35


@export_group("Staff combo")
## One entry per combo hit; the combo length is the array size.
@export var melee_damage: PackedFloat32Array = PackedFloat32Array([14.0, 14.0, 28.0])
@export var melee_knockback: PackedFloat32Array = PackedFloat32Array([4.0, 4.0, 11.0])
## Total duration of each swing in seconds.
@export var melee_swing_time: PackedFloat32Array = PackedFloat32Array([0.3, 0.3, 0.45])
@export var melee_hit_stop: PackedFloat32Array = PackedFloat32Array([0.03, 0.03, 0.07])
## Window (seconds into the swing) where the staff hitbox is live.
@export var melee_active_start: float = 0.06
@export var melee_active_end: float = 0.16
## Forward step at the start of each swing.
@export var melee_lunge_speed: float = 7.0
@export var melee_lunge_time: float = 0.12
## After the last swing ends, a press within this time still continues the combo.
@export var melee_combo_grace: float = 0.25
## Swings snap the fox toward the closest enemy within this range/angle.
@export var melee_snap_range: float = 4.5
@export var melee_snap_angle_deg: float = 75.0

@export_group("Slam and pounce")
## Melee in the air with the stick neutral: hover, then plunge straight down.
@export var slam_hover_time: float = 0.12
@export var slam_fall_speed: float = 32.0
@export var slam_damage: float = 30.0
@export var slam_radius: float = 3.5
@export var slam_knockback: float = 10.0
@export var slam_knockback_up: float = 7.0
@export var slam_recovery: float = 0.3
## Melee in the air with the stick pushed: long-jump arc that slams on landing.
@export var pounce_enabled: bool = true
@export var pounce_speed: float = 15.0
@export var pounce_up_speed: float = 6.0

@export_group("Weapon wheel")
## Game speed while the wheel is open.
@export var wheel_time_scale: float = 0.1
## Stick deflection needed to change the highlighted slot.
@export var wheel_stick_threshold: float = 0.5
## Mouse travel (pixels) needed to change the highlighted slot.
@export var wheel_mouse_threshold: float = 30.0

@export_group("Strafe and zoom")
## Camera pulls in slightly while strafing so the mode change reads.
@export var strafe_camera_distance: float = 4.6
## Scoped weapons (WeaponData.zoom_fov > 0) use this over-the-shoulder view.
@export var zoom_camera_distance: float = 2.4
@export var zoom_shoulder_offset: float = 0.75
@export var zoom_move_multiplier: float = 0.4
@export var zoom_aim_assist_angle_deg: float = 1.0


func jump_velocity() -> float:
	return sqrt(2.0 * gravity * jump_height)


func double_jump_velocity() -> float:
	return sqrt(2.0 * gravity * double_jump_height)
