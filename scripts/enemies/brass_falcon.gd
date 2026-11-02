class_name BrassFalcon
extends Enemy
## Brass Falcon: a dive-bomber.
## Pattern: circle the target at altitude -> windup (hovers, rears up and
## glows; stops tracking near the end so a sidestep/dodge works) -> dive in a
## straight line at where the target was -> pull out and climb back up.
## A dive that misses ploughs into the ground and leaves it grounded, low
## enough for the staff.

@export_group("Circling")
@export var orbit_radius: float = 7.0
@export var orbit_speed: float = 6.0
@export var circle_time: float = 2.0
## Extra random circling time (0..this) so a flock doesn't dive in unison.
@export var circle_jitter: float = 0.8
@export_group("Dive")
@export var windup_time: float = 0.7
## Stop tracking this long before the dive so the player can read it.
@export var windup_lock_time: float = 0.2
@export var windup_rise_speed: float = 1.5
@export var dive_speed: float = 19.0
@export var dive_damage: float = 16.0
@export var dive_knockback: float = 10.0
## The dive carries on this far past the aim point (into the ground on a miss).
@export var dive_overshoot: float = 3.0
@export var recover_time: float = 0.5
@export var grounded_time: float = 1.6

var talon_box: HitBox
var dive_target: Vector3 = Vector3.ZERO
var _dive_dir: Vector3 = Vector3.DOWN
var _dive_time: float = 0.0
var _circle_for: float = 0.0
var _orbit_dir: float = 1.0
var _wings: Array[MeshInstance3D] = []


func _init() -> void:
	display_name = "Brass Falcon"
	body_shape = BodyShape.BOX
	body_size = Vector3(0.7, 0.45, 1.1)
	color = Color(0.32, 0.42, 0.58)
	hurtbox_scale = 1.3
	max_health = 45.0
	move_speed = 6.0
	acceleration = 25.0
	turn_speed_deg = 400.0
	xp_value = 20
	knockback_resistance = 0.2
	flying = true
	hover_height = 6.0
	climb_speed = 5.0
	# Wide raptor cone from up high.
	sight_fov_deg = 200.0
	sight_range = 22.0


func _setup() -> void:
	var e := extents()
	for side: float in [-1.0, 1.0]:
		_wings.append(add_visual_box(Vector3(0.9, 0.06, 0.5), Vector3(side * (e.x * 0.5 + 0.42), e.y * 0.65, 0.05), Color(0.85, 0.65, 0.3)))
	# Tail fan
	add_visual_box(Vector3(0.4, 0.05, 0.35), Vector3(0, e.y * 0.6, e.z * 0.5 + 0.15), Color(0.85, 0.65, 0.3))
	talon_box = make_hit_box("TalonHitBox", e + Vector3(0.4, 0.4, 0.4), Vector3(0, e.y * 0.5, 0), dive_damage, dive_knockback, 4.0)
	talon_box.hit_stop = 0.05
	talon_box.hit_landed.connect(_on_talon_hit)
	_orbit_dir = 1.0 if rng.randf() < 0.5 else -1.0


func _tick_state(delta: float) -> void:
	match state:
		&"idle":
			desired_velocity = Vector3(0, hover_velocity(hover_height), 0)
			if has_target():
				enter_state(&"circle")
		&"circle":
			face_toward(target_position(), delta)
			var to := direction_to_target()
			var d := distance_to_target()
			var radial := clampf((d - orbit_radius) * 2.0, -move_speed, move_speed)
			desired_velocity = to.cross(Vector3.UP) * _orbit_dir * orbit_speed + to * radial
			desired_velocity.y = hover_velocity(hover_height)
			if state_time >= _circle_for and altitude() >= hover_height * 0.7 and d <= orbit_radius + 5.0:
				enter_state(&"windup")
		&"windup":
			desired_velocity = Vector3(0, windup_rise_speed, 0)
			if state_time < windup_time - windup_lock_time:
				face_toward(target_position(), delta, 720.0)
				dive_target = target_position() + Vector3.UP * 0.9
			var t := clampf(state_time / windup_time, 0.0, 1.0)
			telegraph = t
			visual_pitch = 0.4 * t
			visual_scale = Vector3(1.0 + 0.3 * t, 1.0, 0.9)
			if state_time >= windup_time:
				enter_state(&"dive")
		&"dive":
			snap_velocity(_dive_dir * dive_speed)
			visual_pitch = asin(clampf(_dive_dir.y, -1.0, 1.0))
			visual_scale = Vector3(0.6, 1.0, 1.25)
			if state_time >= _dive_time:
				enter_state(&"recover")
		&"recover":
			desired_velocity = Vector3(0, climb_speed, 0)
			if state_time >= recover_time:
				enter_state(&"circle")
		&"grounded":
			desired_velocity = Vector3.ZERO
			visual.rotation.z = sin(state_time * 25.0) * 0.1 * (1.0 - state_time / grounded_time)
			if state_time >= grounded_time:
				visual.rotation.z = 0.0
				enter_state(&"circle")


func _on_enter_state(new_state: StringName) -> void:
	talon_box.active = new_state == &"dive"
	visual.rotation.z = 0.0
	match new_state:
		&"circle":
			_circle_for = circle_time + rng.randf() * circle_jitter
		&"dive":
			var from := get_aim_point()
			_dive_dir = (dive_target - from).normalized()
			_dive_time = (from.distance_to(dive_target) + dive_overshoot) / dive_speed
			GameFeel.shake(0.05)
			Sfx.play(&"dive", from)
		&"recover", &"grounded":
			snap_velocity(Vector3.ZERO)


func _after_move(_delta: float) -> void:
	for wing: MeshInstance3D in _wings:
		var side := signf(wing.position.x)
		var flap := 0.0 if state == &"dive" or state == &"grounded" else sin(_age * 14.0) * 0.45
		wing.rotation.z = side * flap
	if state != &"dive" or state_time < 0.05:
		return
	for i: int in get_slide_collision_count():
		if get_slide_collision(i).get_collider() is CharacterBody3D:
			continue
		GameFeel.shake(0.25)
		GameFeel.impact(global_position + Vector3.UP * 0.3, Color(0.9, 0.8, 0.6), 1.8, 0.25)
		enter_state(&"grounded")
		return


func _on_talon_hit(_hb: HurtBox, _info: DamageInfo) -> void:
	if state == &"dive":
		enter_state(&"recover")


func _can_flinch() -> bool:
	return false


func _state_after_flinch() -> StringName:
	return &"circle"


## Perched hover: a gentle bob while the head (whole body) glances left and right.
func _idle_flavour(_delta: float) -> void:
	var glances: Array[float] = [0.0, 0.6, 0.0, -0.5]
	var i := floori(state_time / 1.1) % glances.size()
	visual_yaw = glances[i]
	visual_offset = Vector3(0.0, 0.1 * sin(state_time * 2.2), 0.0)
