class_name ClockworkRat
extends Enemy
## Clockwork Rat: small, fast pack enemy.
## Pattern: approach -> circle the player for a random time -> quick crouch
## telegraph -> lunge bite -> recover. Flinches when hit, so focus fire breaks
## its rhythm.

@export_group("Pack behaviour")
@export var orbit_radius: float = 3.5
@export var orbit_speed: float = 7.0
@export var min_orbit_time: float = 1.0
@export var max_orbit_time: float = 2.5
@export_group("Lunge")
@export var lunge_windup: float = 0.35
@export var lunge_speed: float = 15.0
@export var lunge_time: float = 0.25
@export var lunge_damage: float = 8.0
@export var recover_time: float = 0.7

var bite_box: HitBox
var _orbit_dir: float = 1.0
var _orbit_duration: float = 1.5


func _init() -> void:
	display_name = "Clockwork Rat"
	body_shape = BodyShape.BOX
	body_size = Vector3(0.55, 0.45, 0.9)
	color = Color(0.55, 0.57, 0.62)
	max_health = 24.0
	move_speed = 9.0
	acceleration = 45.0
	turn_speed_deg = 720.0
	xp_value = 8
	knockback_resistance = 0.0
	flinch_on_hit = true
	hurtbox_scale = 1.15
	# Sharp ears; pack rats scurry about between rests.
	hearing_range = 10.0
	wander_radius = 4.0


func _setup() -> void:
	var e := extents()
	# Wind-up key on its back and a thin tail
	add_visual_box(Vector3(0.05, 0.3, 0.25), Vector3(0, e.y + 0.15, 0.1), Color(0.85, 0.7, 0.3))
	add_visual_box(Vector3(0.06, 0.06, 0.6), Vector3(0, e.y * 0.4, e.z * 0.5 + 0.3), color.darkened(0.3))
	bite_box = make_hit_box("BiteHitBox", Vector3(0.6, 0.5, 0.6), Vector3(0, e.y * 0.5, -e.z * 0.5 - 0.2), lunge_damage, 6.0, 2.0)


func _tick_state(delta: float) -> void:
	match state:
		&"idle":
			desired_velocity = Vector3.ZERO
			if has_target():
				enter_state(&"approach")
		&"approach":
			face_toward(target_position(), delta)
			desired_velocity = direction_to_target() * move_speed
			if distance_to_target() <= orbit_radius + 1.0:
				enter_state(&"orbit")
		&"orbit":
			face_toward(target_position(), delta)
			var to_target := direction_to_target()
			var tangent := to_target.cross(Vector3.UP) * _orbit_dir
			var radial := to_target * (distance_to_target() - orbit_radius)
			desired_velocity = (tangent * orbit_speed + radial * 3.0).limit_length(move_speed)
			if state_time >= _orbit_duration:
				enter_state(&"windup")
		&"windup":
			desired_velocity = Vector3.ZERO
			face_toward(target_position(), delta)
			telegraph = clampf(state_time / lunge_windup, 0.0, 1.0)
			visual_scale = Vector3(1.15, 0.7, 1.1)
			if state_time >= lunge_windup:
				enter_state(&"lunge")
		&"lunge":
			snap_velocity(forward() * lunge_speed)
			visual_scale = Vector3(0.85, 1.0, 1.3)
			if state_time >= lunge_time:
				enter_state(&"recover")
		&"recover":
			desired_velocity = Vector3.ZERO
			if state_time >= recover_time:
				enter_state(&"approach")


func _on_enter_state(new_state: StringName) -> void:
	bite_box.active = new_state == &"lunge"
	match new_state:
		&"orbit":
			_orbit_dir = 1.0 if rng.randf() < 0.5 else -1.0
			_orbit_duration = rng.randf_range(min_orbit_time, max_orbit_time)
		&"recover", FLINCH:
			snap_velocity(Vector3.ZERO)


func _can_flinch() -> bool:
	return state != &"lunge"


func _state_after_flinch() -> StringName:
	return &"approach"


## Twitchy: every so often a quick sideways scurry with a hop and a head flick.
func _idle_flavour(_delta: float) -> void:
	var cycle := 0.9
	var n := floori(state_time / cycle)
	var t := fmod(state_time, cycle)
	var side := 1.0 if n % 2 == 0 else -1.0
	if t < 0.22:
		visual_offset = Vector3(side * 0.18, absf(sin(t / 0.22 * PI)) * 0.08, 0.0)
		visual_yaw = side * 0.35
	else:
		visual_offset = Vector3(side * 0.18, 0.0, 0.0) if t < 0.6 else Vector3.ZERO
		visual_yaw = side * 0.15 * sin(state_time * 40.0) if t > 0.75 else 0.0
