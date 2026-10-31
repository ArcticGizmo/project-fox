class_name BrassBull
extends Enemy
## Brass Bull: a heavy charger.
## Pattern: chase -> windup (glows, lowers head, stops tracking near the end so
## a sidestep/dodge works) -> charge in a straight line -> recover.
## Hitting a wall stuns it, which exposes the boiler weak spot on its back.

@export_group("Charge")
@export var charge_trigger_range: float = 13.0
@export var min_chase_time: float = 0.6
@export var windup_time: float = 0.8
## Stop turning this long before the charge so the player can read it.
@export var windup_lock_time: float = 0.25
@export var charge_speed: float = 20.0
@export var charge_max_time: float = 1.1
@export var charge_damage: float = 25.0
@export var charge_knockback: float = 14.0
@export var recover_time: float = 1.0
@export var stun_time: float = 2.0
@export var weak_spot_multiplier: float = 2.0

var horn_box: HitBox
var weak_spot: HurtBox
var _charge_dir: Vector3 = Vector3.FORWARD


func _init() -> void:
	display_name = "Brass Bull"
	body_shape = BodyShape.BOX
	body_size = Vector3(1.6, 1.5, 2.6)
	color = Color(0.72, 0.52, 0.22)
	max_health = 160.0
	move_speed = 4.5
	acceleration = 20.0
	turn_speed_deg = 180.0
	xp_value = 40
	knockback_resistance = 0.85
	status_resistance = 0.5
	# Spots you from far off but takes its time to notice.
	sight_range = 24.0
	notice_time = 1.8


func _setup() -> void:
	var e := extents()
	# Horns
	add_visual_box(Vector3(0.18, 0.18, 0.6), Vector3(-e.x * 0.42, e.y * 0.9, -e.z * 0.5 - 0.1), Color(0.95, 0.9, 0.75))
	add_visual_box(Vector3(0.18, 0.18, 0.6), Vector3(e.x * 0.42, e.y * 0.9, -e.z * 0.5 - 0.1), Color(0.95, 0.9, 0.75))
	# Boiler on its back = weak spot
	add_visual_box(Vector3(0.7, 0.4, 0.8), Vector3(0, e.y + 0.2, e.z * 0.2), Color(0.9, 0.35, 0.1))
	horn_box = make_hit_box("HornHitBox", Vector3(e.x + 0.3, e.y * 0.8, 1.0), Vector3(0, e.y * 0.5, -e.z * 0.5 - 0.3), charge_damage, charge_knockback, 5.0)
	horn_box.hit_stop = 0.06
	horn_box.hit_landed.connect(_on_horn_hit)
	weak_spot = make_weak_spot(Vector3(0.8, 0.5, 0.9), Vector3(0, e.y + 0.2, e.z * 0.2), weak_spot_multiplier)


func _tick_state(delta: float) -> void:
	match state:
		&"idle":
			desired_velocity = Vector3.ZERO
			if has_target():
				enter_state(&"chase")
		&"chase":
			face_toward(target_position(), delta)
			desired_velocity = forward() * move_speed
			if state_time >= min_chase_time and distance_to_target() <= charge_trigger_range:
				enter_state(&"windup")
		&"windup":
			desired_velocity = Vector3.ZERO
			if state_time < windup_time - windup_lock_time:
				face_toward(target_position(), delta, 240.0)
			telegraph = clampf(state_time / windup_time, 0.0, 1.0)
			visual_scale = Vector3(1.05, 0.85, 1.1)
			if state_time >= windup_time:
				enter_state(&"charge")
		&"charge":
			snap_velocity(_charge_dir * charge_speed)
			if state_time >= charge_max_time:
				enter_state(&"recover")
		&"recover":
			desired_velocity = Vector3.ZERO
			if state_time >= recover_time:
				enter_state(&"chase")
		&"stunned":
			desired_velocity = Vector3.ZERO
			visual.rotation.z = sin(state_time * 25.0) * 0.08 * (1.0 - state_time / stun_time)
			if state_time >= stun_time:
				visual.rotation.z = 0.0
				enter_state(&"chase")


func _on_enter_state(new_state: StringName) -> void:
	horn_box.active = new_state == &"charge"
	if new_state == &"charge":
		_charge_dir = forward()
		GameFeel.shake(0.1)
	elif new_state == &"recover" or new_state == &"stunned":
		snap_velocity(Vector3.ZERO)


func _after_move(_delta: float) -> void:
	if state != &"charge" or state_time < 0.05:
		return
	for i: int in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_collider() is CharacterBody3D:
			continue
		if col.get_normal().dot(_charge_dir) < -0.6:
			GameFeel.shake(0.6)
			GameFeel.impact(global_position + _charge_dir * extents().z * 0.5 + Vector3.UP, Color(1, 0.9, 0.6), 2.0, 0.25)
			enter_state(&"stunned")
			return


func _on_horn_hit(_hb: HurtBox, _info: DamageInfo) -> void:
	if state == &"charge":
		enter_state(&"recover")


func _can_flinch() -> bool:
	return false


## Grazing: the head dips nose-down for a while, then comes back up to look around.
func _idle_flavour(_delta: float) -> void:
	var t := fmod(state_time, 3.2)
	var dip := smoothstep(0.3, 0.8, t) * (1.0 - smoothstep(1.9, 2.4, t))
	visual_pitch = -0.28 * dip
