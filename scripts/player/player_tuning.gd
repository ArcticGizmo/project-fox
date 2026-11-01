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
## Melee in the air (stick neutral, or any stick while the pounce is off): hover,
## then plunge straight down.
@export var slam_hover_time: float = 0.12
@export var slam_fall_speed: float = 32.0
@export var slam_damage: float = 30.0
@export var slam_radius: float = 3.5
@export var slam_knockback: float = 10.0
@export var slam_knockback_up: float = 7.0
@export var slam_recovery: float = 0.3
## How far the slam landing is heard by unaware enemies.
@export var slam_noise_radius: float = 12.0
## Melee in the air with the stick pushed: long-jump arc that slams on landing.
## Off for now so the slam never carries you forward.
@export var pounce_enabled: bool = false
@export var pounce_speed: float = 15.0
@export var pounce_up_speed: float = 6.0

@export_group("Grapple")
## Brass Grapple-Tail (GrappleTail). Rings count when within this distance of
## the fox's reel point (grapple_hang_height above the feet)...
@export var grapple_range: float = 15.0
## ...but not closer than this (the ring you are standing next to).
@export var grapple_min_distance: float = 2.0
## ...and within this horizontal angle of the camera's forward direction.
@export var grapple_aim_cone_deg: float = 60.0
## Rings this far below the feet (or lower) are ignored: the tail pulls up and across.
@export var grapple_max_drop: float = 1.0
## Point on the fox (height above the feet) that is reeled to the ring.
@export var grapple_hang_height: float = 1.0
## Tail flying out to the ring; the fox hangs in the air meanwhile.
@export var grapple_throw_time: float = 0.08
## Reel: accelerates from grapple_reel_start_speed to grapple_reel_speed...
@export var grapple_reel_start_speed: float = 8.0
@export var grapple_reel_speed: float = 22.0
@export var grapple_reel_acceleration: float = 90.0
## ...and eases down to grapple_arrive_speed over the last grapple_ease_distance.
@export var grapple_ease_distance: float = 2.5
@export var grapple_arrive_speed: float = 7.0
## Let go this close to the ring.
@export var grapple_release_distance: float = 0.6
## Release: a hop of this height (not cut short by releasing jump)...
@export var grapple_release_hop_height: float = 1.0
## ...carrying this much of the reel direction horizontally (m/s), onto the ledge.
@export var grapple_release_carry: float = 1.5
## For this long after the release (or until landing) air control is scaled by
## grapple_release_air_control, so holding forward settles on the ledge.
@export var grapple_release_settle_time: float = 0.5
@export var grapple_release_air_control: float = 0.15
## Give up a reel that has not arrived after this long (stuck on geometry).
@export var grapple_max_time: float = 1.6
## Hits with at least this knockback knock the fox off the line (smaller ones are shrugged off).
@export var grapple_cancel_knockback: float = 6.0
## Camera vertical follow while reeling (normal follow lags a fast climb).
@export var grapple_camera_vertical_sharpness: float = 14.0

@export_group("Glide")
## Leaf-wing Cloak (LeafCloak). Hold jump while falling once the double jump is
## spent: the cloak opens. Fall speed eases to glide_fall_speed (m/s down)...
@export var glide_fall_speed: float = 2.5
## ...at this rate (m/s per second), also used for vent lift.
@export var glide_vertical_acceleration: float = 30.0
## Forward speed along the glide heading, reached at glide_acceleration.
@export var glide_speed: float = 9.0
@export var glide_acceleration: float = 12.0
## Forward speed with the stick released (drift), so a glider can ride a vent.
@export var glide_idle_speed: float = 0.5
## The heading turns toward the camera-relative stick at this rate (gentle).
@export var glide_turn_speed_deg: float = 150.0
## Rise speed in the full part of a SteamVent updraft while gliding.
@export var glide_vent_rise_speed: float = 7.0
## Upward acceleration (m/s^2) a vent gives a fox that is NOT gliding (a nudge).
@export var vent_push_acceleration: float = 3.0
## Hits with at least this knockback (or any upward knockback) fold the cloak.
@export var glide_cancel_knockback: float = 1.0
## Wing unfold / fold time (visual).
@export var glide_unfold_time: float = 0.15

@export_group("Burrow")
## Burrow Claws (BurrowClaws). With the gadget, a floor dodge on a SoilPatch
## dives underground: the fox sinks over burrow_dive_time (no control)...
@export var burrow_dive_time: float = 0.2
## ...then moves under the patch (never off it) at this speed.
@export var burrow_move_speed: float = 3.5
@export var burrow_acceleration: float = 30.0
## Dodge on a linked patch tunnels to its partner at this speed, taking at least
## burrow_tunnel_min_time (arrives still underground).
@export var burrow_tunnel_speed: float = 9.0
@export var burrow_tunnel_min_time: float = 0.45
## Jump (or dodge on a standalone patch) pops out with a hop this high.
@export var burrow_pop_hop_height: float = 0.7
## After popping out the fox stays unseen this long (so a point-blank enemy does
## not notice it before the sneak swing lands).
@export var burrow_surface_conceal_time: float = 0.75
## The first staff swing hit within this time of popping out...
@export var burrow_sneak_window: float = 1.5
## ...deals this much more damage to an unaware enemy.
@export var burrow_sneak_multiplier: float = 2.5

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


func burrow_pop_velocity() -> float:
	return sqrt(2.0 * gravity * burrow_pop_hop_height)


func grapple_hop_velocity() -> float:
	return sqrt(2.0 * gravity * grapple_release_hop_height)
