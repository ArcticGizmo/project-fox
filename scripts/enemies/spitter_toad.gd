class_name SpitterToad
extends Enemy
## Spitter Toad: artillery.
## Pattern: keep 9-16m away (backs off, strafes) -> inflate telegraph -> lob a
## glob at where the player is heading. A red disc marks the landing zone for
## the whole flight. Every Nth attack is a 3-glob volley.

@export_group("Spacing")
@export var preferred_min: float = 9.0
@export var preferred_max: float = 16.0
@export var strafe_switch_time: float = 2.0
@export_group("Lob")
@export var attack_cooldown: float = 2.2
@export var windup_time: float = 0.7
@export var recover_time: float = 0.5
@export var lob_flight_time: float = 1.1
@export var lob_damage: float = 18.0
@export var lob_radius: float = 2.2
## 0 = aim at current position, 1 = full lead on current velocity.
@export var lead_factor: float = 0.6
@export var volley_every: int = 3
@export var volley_spacing: float = 2.8

var attack_count: int = 0
var _strafe_dir: float = 1.0


func _init() -> void:
	display_name = "Spitter Toad"
	body_shape = BodyShape.SPHERE
	body_size = Vector3(1.4, 1.4, 1.4)
	color = Color(0.3, 0.68, 0.35)
	max_health = 70.0
	move_speed = 3.5
	acceleration = 20.0
	turn_speed_deg = 300.0
	xp_value = 25
	knockback_resistance = 0.3
	flinch_on_hit = true
	flinch_time = 0.2


func _setup() -> void:
	var e := extents()
	# Brass throat-bellows
	add_visual_box(Vector3(0.5, 0.35, 0.3), Vector3(0, e.y * 0.3, -e.z * 0.42), Color(0.8, 0.65, 0.3))


func _tick_state(delta: float) -> void:
	match state:
		&"idle":
			desired_velocity = Vector3.ZERO
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
				desired_velocity = to.cross(Vector3.UP) * _strafe_dir * move_speed * 0.6
			if fmod(state_time, strafe_switch_time) < delta:
				_strafe_dir = -_strafe_dir
			if state_time >= attack_cooldown and d <= preferred_max + 6.0:
				enter_state(&"windup")
		&"windup":
			desired_velocity = Vector3.ZERO
			face_toward(target_position(), delta)
			var t := clampf(state_time / windup_time, 0.0, 1.0)
			telegraph = t
			visual_scale = Vector3.ONE * (1.0 + 0.35 * t)
			if state_time >= windup_time:
				_attack()
				enter_state(&"recover")
		&"recover":
			desired_velocity = Vector3.ZERO
			if state_time >= recover_time:
				enter_state(&"reposition")


func is_volley_attack(index: int) -> bool:
	return volley_every > 0 and index % volley_every == volley_every - 1


func predicted_target_point() -> Vector3:
	return lead_target(lob_flight_time * lead_factor)


func _attack() -> void:
	var center := predicted_target_point()
	var points: Array[Vector3] = [center]
	if is_volley_attack(attack_count):
		var side := direction_to_target().cross(Vector3.UP)
		points.append(center + side * volley_spacing)
		points.append(center - side * volley_spacing)
	attack_count += 1
	var mouth := global_position + Vector3.UP * extents().y * 0.6 + forward() * extents().z * 0.5
	for p: Vector3 in points:
		LobProjectile.launch(self, mouth, ground_point(p), lob_flight_time, lob_damage, lob_radius)
	visual_scale = Vector3(0.8, 0.8, 0.8)


func _can_flinch() -> bool:
	return state == &"windup"


func _state_after_flinch() -> StringName:
	return &"reposition"
