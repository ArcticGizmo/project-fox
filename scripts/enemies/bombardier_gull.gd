class_name BombardierGull
extends Enemy
## Bombardier Gull: airborne artillery.
## Pattern: hold 7-13m away at altitude, drifting sideways -> windup (puffs up
## and glows) -> lob a bomb at where the target is heading. Every Nth attack is
## a barrage: a line of bombs that walks from in front of the target to behind
## it, so running straight at or away from the gull gets you caught.

@export_group("Spacing")
@export var preferred_min: float = 7.0
@export var preferred_max: float = 13.0
@export var drift_switch_time: float = 1.8
@export var bob_height: float = 0.4
@export_group("Bombs")
@export var attack_cooldown: float = 2.4
@export var windup_time: float = 0.6
@export var recover_time: float = 0.5
@export var lob_flight_time: float = 1.0
@export var lob_damage: float = 14.0
@export var lob_radius: float = 2.0
## 0 = aim at current position, 1 = full lead on current velocity.
@export var lead_factor: float = 0.6
@export var barrage_every: int = 3
@export var barrage_count: int = 3
@export var barrage_spacing: float = 2.6
## Each later bomb in a barrage lands this much later.
@export var barrage_stagger: float = 0.2

var attack_count: int = 0
var _drift_dir: float = 1.0


func _init() -> void:
	display_name = "Bombardier Gull"
	body_shape = BodyShape.SPHERE
	body_size = Vector3(1.0, 1.0, 1.0)
	color = Color(0.9, 0.9, 0.84)
	hurtbox_scale = 1.2
	max_health = 55.0
	move_speed = 4.0
	acceleration = 15.0
	turn_speed_deg = 300.0
	xp_value = 30
	knockback_resistance = 0.3
	flinch_on_hit = true
	flinch_time = 0.2
	flying = true
	hover_height = 6.5
	climb_speed = 4.0


func _setup() -> void:
	var e := extents()
	for side: float in [-1.0, 1.0]:
		add_visual_box(Vector3(1.1, 0.06, 0.45), Vector3(side * (e.x * 0.5 + 0.45), e.y * 0.6, 0.05), Color(0.55, 0.58, 0.62))
	# Brass bomb hopper slung underneath
	add_visual_box(Vector3(0.45, 0.35, 0.45), Vector3(0, 0.0, 0.05), Color(0.8, 0.6, 0.25))
	_drift_dir = 1.0 if rng.randf() < 0.5 else -1.0


func _tick_state(delta: float) -> void:
	var cruise := hover_velocity(hover_height + sin(_age * 2.0) * bob_height)
	match state:
		&"idle":
			desired_velocity = Vector3(0, cruise, 0)
			if has_target():
				enter_state(&"reposition")
		&"reposition":
			face_toward(target_position(), delta)
			var d := distance_to_target()
			var to := direction_to_target()
			if d < preferred_min:
				desired_velocity = -to * move_speed
			elif d > preferred_max:
				desired_velocity = to * move_speed
			else:
				desired_velocity = to.cross(Vector3.UP) * _drift_dir * move_speed * 0.6
			desired_velocity.y = cruise
			if fmod(state_time, drift_switch_time) < delta:
				_drift_dir = -_drift_dir
			if state_time >= attack_cooldown and d <= preferred_max + 6.0 and altitude() >= hover_height * 0.6:
				enter_state(&"windup")
		&"windup":
			desired_velocity = Vector3.ZERO
			face_toward(target_position(), delta)
			var t := clampf(state_time / windup_time, 0.0, 1.0)
			telegraph = t
			visual_scale = Vector3.ONE * (1.0 + 0.3 * t)
			if state_time >= windup_time:
				_attack()
				enter_state(&"recover")
		&"recover":
			desired_velocity = Vector3(0, cruise, 0)
			if state_time >= recover_time:
				enter_state(&"reposition")


func is_barrage_attack(index: int) -> bool:
	return barrage_every > 0 and index % barrage_every == barrage_every - 1


func predicted_target_point() -> Vector3:
	return lead_target(lob_flight_time * lead_factor)


## Landing points for an attack, in landing order (near to far for a barrage).
func bomb_points(index: int) -> Array[Vector3]:
	var center := predicted_target_point()
	if not is_barrage_attack(index):
		var single: Array[Vector3] = [center]
		return single
	var out: Array[Vector3] = []
	var away := direction_to_target()
	for i: int in barrage_count:
		out.append(center + away * barrage_spacing * (float(i) - (barrage_count - 1) * 0.5))
	return out


func _attack() -> void:
	var points := bomb_points(attack_count)
	attack_count += 1
	var hopper := global_position + forward() * 0.2
	for i: int in points.size():
		LobProjectile.launch(self, hopper, ground_point(points[i]), lob_flight_time + barrage_stagger * i, lob_damage, lob_radius)
	visual_scale = Vector3(0.85, 0.85, 0.85)


func _can_flinch() -> bool:
	return state == &"windup"


func _state_after_flinch() -> StringName:
	return &"reposition"


## Circles its roost: the body orbits a small loop around home, nose along the loop.
func _idle_flavour(_delta: float) -> void:
	var a := state_time * 0.9
	visual_offset = Vector3(cos(a) - 1.0, 0.15 * sin(a * 2.0), sin(a)) * 0.9
	visual_yaw = wrapf(PI - a, -PI, PI)
