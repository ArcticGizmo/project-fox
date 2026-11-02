class_name ClockworkHoneybee
extends Enemy
## Clockwork Honeybee: a fragile swarm flyer that hovers low and takes turns.
## Pattern: hover round the target at orbit_radius, bobbing -> windup (stops, rears back,
## glows; stops tracking near the end so a sidestep or dodge works) -> sting: a straight
## dart through where the target was -> recover (brakes, climbs back) -> hover.
## Swarm rule: a bee only winds up when no other honeybee within swarm_radius is winding
## up or stinging, so a swarm attacks one at a time in a rhythm you can read.
## One good hit pops it; hits flinch it out of its windup.

const MODEL: PackedScene = preload("res://assets/enemies/clockwork_honeybee/Clockwork_Honeybee.glb")
## The model's wings reach past the body box.
const MODEL_FIT := Vector3(1.1, 0.8, 0.9)

@export_group("Hover")
@export var orbit_radius: float = 5.0
@export var orbit_speed: float = 4.5
@export var bob_height: float = 0.35
@export var sting_cooldown: float = 1.6
@export var swarm_radius: float = 12.0
@export_group("Sting")
@export var windup_time: float = 0.55
## Stop turning this long before the dart.
@export var windup_lock_time: float = 0.15
@export var sting_speed: float = 16.0
@export var sting_damage: float = 8.0
@export var sting_knockback: float = 5.0
## How far past the aim point the dart carries.
@export var sting_overshoot: float = 2.0
@export var recover_time: float = 0.6

var stinger_box: HitBox
## Where the dart is aimed (locked windup_lock_time before it).
var sting_target: Vector3 = Vector3.ZERO
var _sting_dir: Vector3 = Vector3.FORWARD
var _sting_time: float = 0.0
var _orbit_dir: float = 1.0


func _init() -> void:
	display_name = "Clockwork Honeybee"
	body_shape = BodyShape.BOX
	body_size = Vector3(0.7, 0.6, 0.8)
	color = Color(0.85, 0.65, 0.25)
	max_health = 18.0
	move_speed = 6.0
	acceleration = 25.0
	turn_speed_deg = 540.0
	xp_value = 8
	flying = true
	hover_height = 2.4
	flinch_on_hit = true
	flinch_time = 0.25
	hurtbox_scale = 1.2
	sight_range = 16.0
	hearing_range = 8.0


func _make_model() -> Node3D:
	return fit_model(MODEL, MODEL_FIT)


func _setup() -> void:
	var e := extents()
	stinger_box = make_hit_box("StingerHitBox", e + Vector3(0.3, 0.3, 0.3), Vector3(0, e.y * 0.5, 0), sting_damage, sting_knockback, 2.0)
	stinger_box.hit_landed.connect(_on_sting_hit)
	_orbit_dir = 1.0 if rng.randf() < 0.5 else -1.0


func _tick_state(delta: float) -> void:
	match state:
		&"idle":
			desired_velocity = Vector3(0, hover_velocity(hover_height), 0)
			if has_target():
				enter_state(&"hover")
		&"hover":
			face_toward(target_position(), delta)
			var to := direction_to_target()
			var radial := clampf((distance_to_target() - orbit_radius) * 2.0, -move_speed, move_speed)
			desired_velocity = to.cross(Vector3.UP) * _orbit_dir * orbit_speed + to * radial
			desired_velocity.y = hover_velocity(hover_height + sin(_age * 3.0) * bob_height)
			if state_time >= sting_cooldown and distance_to_target() <= orbit_radius + 4.0 and not swarm_busy():
				enter_state(&"windup")
		&"windup":
			desired_velocity = Vector3.ZERO
			if state_time < windup_time - windup_lock_time:
				face_toward(target_position(), delta, 720.0)
				sting_target = target_position() + Vector3.UP * 0.9
			var t := clampf(state_time / windup_time, 0.0, 1.0)
			telegraph = t
			visual_pitch = -0.35 * t
			visual_offset = -Vector3.FORWARD * 0.25 * t
			if state_time >= windup_time:
				enter_state(&"sting")
		&"sting":
			snap_velocity(_sting_dir * sting_speed)
			visual_pitch = asin(clampf(_sting_dir.y, -1.0, 1.0))
			visual_scale = Vector3(0.8, 0.8, 1.25)
			if state_time >= _sting_time:
				enter_state(&"recover")
		&"recover":
			desired_velocity = Vector3(0, climb_speed * 0.5, 0)
			if state_time >= recover_time:
				enter_state(&"hover")


func _on_enter_state(new_state: StringName) -> void:
	stinger_box.active = new_state == &"sting"
	match new_state:
		&"sting":
			var from := get_aim_point()
			_sting_dir = (sting_target - from).normalized()
			_sting_time = (from.distance_to(sting_target) + sting_overshoot) / sting_speed
			Sfx.play(&"dive", from)
		&"recover":
			snap_velocity(Vector3.ZERO)
			_orbit_dir = -_orbit_dir


## Winding up or stinging (the swarm's turn).
func is_attacking() -> bool:
	return state == &"windup" or state == &"sting"


## Another honeybee nearby is taking its turn.
func swarm_busy() -> bool:
	for e: Enemy in Enemy.in_radius(get_tree(), global_position, swarm_radius):
		if e != self and e is ClockworkHoneybee and (e as ClockworkHoneybee).is_attacking():
			return true
	return false


func _on_sting_hit(_hb: HurtBox, _info: DamageInfo) -> void:
	if state == &"sting":
		enter_state(&"recover")


func _after_move(_delta: float) -> void:
	# A dart that hits the ground or a wall ends there.
	if state != &"sting" or state_time < 0.05:
		return
	for i: int in get_slide_collision_count():
		if not get_slide_collision(i).get_collider() is CharacterBody3D:
			enter_state(&"recover")
			return


func _can_flinch() -> bool:
	return state == &"hover" or state == &"windup"


func _state_after_flinch() -> StringName:
	return &"hover"


## A lazy figure-eight over its home with a quick buzz now and then.
func _idle_flavour(_delta: float) -> void:
	visual_offset = Vector3(sin(state_time * 1.3) * 0.15, sin(state_time * 2.6) * 0.1, 0.0)
	var buzz := fmod(state_time, 2.2) < 0.2
	visual_yaw = sin(state_time * 40.0) * 0.06 if buzz else 0.0
