class_name FurnaceStag
extends Enemy
## Furnace Stag: the first boss. A brass stag with a furnace in its chest and
## lightning-coil antlers, fought in three phases split by health. Each phase
## change is a roar (no damage taken, attacks cancelled).
##   1 Armoured (to phase_2_at): the antler guard turns aside frontal hits
##     (guard_factor); the back vent is a weak spot. Attacks: antler sweep
##     (close, wide frontal arc) and stomp (rears up, slams: an expanding
##     Shockwave ring you jump over).
##   2 Furnace open (to phase_3_at): no guard; the chest furnace opens as a big
##     weak spot. Adds an ember barrage (lobs around you) and a charge that
##     stuns it against walls and pillars.
##   3 Overheat: wind-ups shorten (phase_pace) and antler lightning marks spots
##     ahead of you that strike after a beat (DelayedStrike).
## Too heavy to upend, except while rearing for a stomp: a full-charge Rhino
## Beetle Ram then topples it (exposed, toppled_time).
## Every attack state starts with a `<name>_windup` state that glows.

signal phase_changed(phase: int)

const FURNACE_COLOR := Color(1.0, 0.45, 0.1)
const ANTLER_COLOR := Color(0.85, 0.75, 0.45)
const PHASE_NAMES: Array[String] = ["", "Armoured", "Furnace open", "Overheat"]

@export_group("Phases")
@export_range(0.0, 1.0) var phase_2_at: float = 0.66
@export_range(0.0, 1.0) var phase_3_at: float = 0.33
@export var roar_time: float = 1.6
## Wind-up / recovery time multiplier per phase (index = phase).
@export var phase_pace: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 0.9, 0.75])
@export_group("Armour")
@export var guard_arc_deg: float = 120.0
@export var guard_factor: float = 0.4
@export var vent_multiplier: float = 2.0
@export var furnace_multiplier: float = 2.5
@export_group("Rhythm")
@export var attack_gap: float = 1.2
@export var recover_time: float = 0.9
@export var stalk_range: float = 5.0
@export_group("Sweep")
@export var sweep_range: float = 6.5
@export var sweep_windup_time: float = 0.75
@export var sweep_active_time: float = 0.25
@export var sweep_damage: float = 22.0
@export var sweep_knockback: float = 12.0
@export_group("Stomp")
@export var stomp_windup_time: float = 1.0
@export var shockwave_speed: float = 9.0
@export var shockwave_radius: float = 18.0
@export var shockwave_damage: float = 18.0
@export var toppled_time: float = 2.5
@export_group("Barrage")
@export var barrage_windup_time: float = 0.8
@export var barrage_count: int = 5
@export var barrage_spread: float = 4.0
@export var barrage_flight_time: float = 1.2
@export var barrage_damage: float = 16.0
@export var barrage_radius: float = 2.2
@export_group("Charge")
@export var charge_min_range: float = 9.0
@export var charge_windup_time: float = 0.9
@export var charge_lock_time: float = 0.25
@export var charge_speed: float = 17.0
@export var charge_max_time: float = 1.4
@export var charge_damage: float = 28.0
@export var stun_time: float = 2.5
@export_group("Lightning")
@export var strike_windup_time: float = 0.7
@export var strike_count: int = 3
@export var strike_scatter: float = 5.0
@export var strike_delay: float = 0.9
@export var strike_radius: float = 2.2
@export var strike_damage: float = 20.0

var phase: int = 1
## Attacks started, in order (tests and tuning).
var attack_log: Array[StringName] = []
var sweep_box: HitBox
var charge_box: HitBox
var vent: HurtBox
var furnace: HurtBox
var last_shockwave: Shockwave = null
var last_strikes: Array[DelayedStrike] = []
var _last_attack: StringName = &""
var _forced: StringName = &""
var _charge_dir: Vector3 = Vector3.FORWARD
var _furnace_mat: StandardMaterial3D
var _antler_mat: StandardMaterial3D
var _grille: Node3D


func _init() -> void:
	display_name = "Furnace Stag"
	body_shape = BodyShape.BOX
	body_size = Vector3(2.4, 2.6, 4.2)
	color = Color(0.42, 0.33, 0.26)
	max_health = 1200.0
	move_speed = 3.2
	acceleration = 14.0
	turn_speed_deg = 110.0
	xp_value = 300
	knockback_resistance = 1.0
	status_resistance = 0.3
	sight_range = 32.0
	sight_fov_deg = 170.0
	notice_time = 0.4
	alert_radius = 0.0
	leash_radius = 80.0
	forget_time = 0.0


func _setup() -> void:
	add_to_group(&"bosses")
	var e := extents()
	# Legs
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			add_visual_box(Vector3(0.4, 1.0, 0.4), Vector3(sx * e.x * 0.35, 0.2, sz * e.z * 0.32), color.darkened(0.4))
	# Neck and head, raised at the front
	add_visual_box(Vector3(1.0, 1.4, 1.0), Vector3(0, e.y + 0.4, -e.z * 0.42), color.lightened(0.1))
	add_visual_box(Vector3(0.9, 0.7, 1.4), Vector3(0, e.y + 1.0, -e.z * 0.55), color.lightened(0.15))
	# Antlers: tines branching up and out from the head
	_antler_mat = StandardMaterial3D.new()
	_antler_mat.albedo_color = ANTLER_COLOR
	_antler_mat.metallic = 0.6
	_antler_mat.emission_enabled = true
	_antler_mat.emission = Color.BLACK
	for sx: float in [-1.0, 1.0]:
		for t: int in 3:
			var tine := add_visual_box(Vector3(0.14, 1.0 - 0.15 * t, 0.14), Vector3(sx * (0.5 + 0.35 * t), e.y + 1.7 + 0.25 * t, -e.z * 0.55 + 0.15 * t), ANTLER_COLOR)
			tine.rotation.z = -sx * (0.35 + 0.25 * t)
			tine.material_override = _antler_mat
	# Chest furnace (front, low) behind a grille that falls away in phase 2
	var chest := add_visual_box(Vector3(1.4, 1.1, 0.3), Vector3(0, e.y * 0.45, -e.z * 0.5 - 0.1), FURNACE_COLOR)
	_furnace_mat = StandardMaterial3D.new()
	_furnace_mat.albedo_color = FURNACE_COLOR.darkened(0.4)
	_furnace_mat.emission_enabled = true
	_furnace_mat.emission = FURNACE_COLOR * 0.3
	chest.material_override = _furnace_mat
	_grille = Node3D.new()
	visual.add_child(_grille)
	for i: int in 4:
		var bar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.1, 1.2, 0.1)
		bar.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color.darkened(0.5)
		bar.material_override = mat
		bar.position = Vector3(-0.5 + i * 0.33, e.y * 0.45, -e.z * 0.5 - 0.3)
		_grille.add_child(bar)
	# Back vent (always a weak spot)
	add_visual_box(Vector3(0.9, 0.35, 0.9), Vector3(0, e.y + 0.15, e.z * 0.25), FURNACE_COLOR)

	sweep_box = make_hit_box("SweepHitBox", Vector3(8.0, 2.5, 5.0), Vector3(0, 1.25, -e.z * 0.5 - 2.3), sweep_damage, sweep_knockback, 4.0)
	sweep_box.hit_stop = 0.06
	charge_box = make_hit_box("ChargeHitBox", Vector3(e.x + 0.6, e.y, 1.4), Vector3(0, e.y * 0.5, -e.z * 0.5 - 0.6), charge_damage, 15.0, 6.0)
	charge_box.hit_stop = 0.08
	charge_box.hit_landed.connect(func(_hb: HurtBox, _info: DamageInfo) -> void:
		if state == &"charge":
			enter_state(&"recover"))
	vent = make_weak_spot(Vector3(1.1, 0.6, 1.1), Vector3(0, e.y + 0.15, e.z * 0.25), vent_multiplier)
	vent.name = "Vent"
	furnace = make_weak_spot(Vector3(1.5, 1.2, 0.6), Vector3(0, e.y * 0.45, -e.z * 0.5 - 0.1), furnace_multiplier)
	furnace.name = "Furnace"
	furnace.set_deferred(&"monitorable", false)


## Phase from the health fraction (the phase the stag should be in).
func phase_for_health() -> int:
	var f := health.current / health.max_health
	return 3 if f <= phase_3_at else (2 if f <= phase_2_at else 1)


func pace() -> float:
	return phase_pace[clampi(phase, 0, phase_pace.size() - 1)]


func phase_name() -> String:
	return PHASE_NAMES[clampi(phase, 0, PHASE_NAMES.size() - 1)]


## The next attack starts as soon as the stag is free (tests, screenshots).
func force_attack(attack: StringName) -> void:
	_forced = attack
	if state == &"stalk" or state == &"idle" or state == &"recover":
		_start_attack(attack)


func is_guarding() -> bool:
	return phase == 1 and state != &"roar" and state != &"toppled" and state != &"stunned" and not is_disabled()


func _modify_incoming(info: DamageInfo) -> void:
	super(info)
	if info.is_dot or not is_guarding():
		return
	var to := info.source_position - global_position
	to.y = 0.0
	if to.length_squared() > 0.0001 and rad_to_deg(forward().angle_to(to.normalized())) <= guard_arc_deg * 0.5:
		info.amount *= guard_factor
		info.is_critical = false


func _hit_sound(info: DamageInfo) -> StringName:
	var to := info.source_position - global_position
	to.y = 0.0
	if is_guarding() and to.length_squared() > 0.0001 and rad_to_deg(forward().angle_to(to.normalized())) <= guard_arc_deg * 0.5:
		return &"clank"
	return super(info)


## Only a stomp wind-up (reared on its hind legs) can be knocked over.
func upend(_duration: float) -> void:
	if health.is_dead or state != &"stomp_windup":
		return
	_interrupt()
	enter_state(&"toppled")


func _tick_state(delta: float) -> void:
	if state != &"roar" and phase_for_health() > phase:
		_interrupt()
		enter_state(&"roar")
		return
	var p := pace()
	match state:
		&"idle":
			desired_velocity = Vector3.ZERO
			if has_target():
				enter_state(&"stalk")
		&"stalk":
			face_toward(target_position(), delta)
			desired_velocity = forward() * move_speed if distance_to_target() > stalk_range else Vector3.ZERO
			if _forced != &"":
				_start_attack(_forced)
			elif state_time >= attack_gap * p and has_target():
				_start_attack(_next_attack())
		&"sweep_windup":
			desired_velocity = Vector3.ZERO
			face_toward(target_position(), delta)
			_windup(sweep_windup_time * p)
			visual_pitch = -0.25 * telegraph
			visual_yaw = 0.35 * telegraph
			if state_time >= sweep_windup_time * p:
				enter_state(&"sweep")
		&"sweep":
			visual_yaw = lerpf(0.35, -0.6, clampf(state_time / sweep_active_time, 0.0, 1.0))
			if state_time >= sweep_active_time:
				enter_state(&"recover")
		&"stomp_windup":
			desired_velocity = Vector3.ZERO
			_windup(stomp_windup_time * p)
			visual_pitch = 0.45 * telegraph
			visual_offset = Vector3.UP * 0.6 * telegraph
			if state_time >= stomp_windup_time * p:
				enter_state(&"stomp")
		&"stomp":
			if state_time >= 0.15:
				enter_state(&"recover")
		&"barrage_windup":
			desired_velocity = Vector3.ZERO
			face_toward(target_position(), delta)
			_windup(barrage_windup_time * p)
			visual_scale = Vector3(1.0 + 0.1 * telegraph, 1.0 - 0.08 * telegraph, 1.0)
			if state_time >= barrage_windup_time * p:
				_fire_barrage()
				enter_state(&"recover")
		&"charge_windup":
			desired_velocity = Vector3.ZERO
			if state_time < (charge_windup_time - charge_lock_time) * p:
				face_toward(target_position(), delta, 200.0)
			_windup(charge_windup_time * p)
			visual_scale = Vector3(1.05, 0.88, 1.08)
			visual_pitch = -0.15 * telegraph
			if state_time >= charge_windup_time * p:
				enter_state(&"charge")
		&"charge":
			snap_velocity(_charge_dir * charge_speed)
			if state_time >= charge_max_time:
				enter_state(&"recover")
		&"strike_windup":
			desired_velocity = Vector3.ZERO
			face_toward(target_position(), delta)
			_windup(strike_windup_time * p)
			_antler_mat.emission = DelayedStrike.COLOR * 3.0 * telegraph
			if state_time >= strike_windup_time * p:
				_call_lightning()
				enter_state(&"recover")
		&"recover":
			desired_velocity = Vector3.ZERO
			if state_time >= recover_time * p:
				enter_state(&"stalk")
		&"stunned", &"toppled":
			desired_velocity = Vector3.ZERO
			visual.rotation.z = sin(state_time * 20.0) * 0.05 * (0.4 if state == &"stunned" else 1.0)
			if state == &"toppled":
				visual.rotation.z += 0.5
			if state_time >= (stun_time if state == &"stunned" else toppled_time):
				visual.rotation.z = 0.0
				enter_state(&"stalk")
		&"roar":
			desired_velocity = Vector3.ZERO
			telegraph = 0.5 + 0.5 * sin(state_time * 18.0)
			visual_pitch = 0.3
			if state_time >= roar_time:
				_set_phase(phase_for_health())
				enter_state(&"stalk")


func _windup(total: float) -> void:
	telegraph = clampf(state_time / maxf(0.01, total), 0.0, 1.0)


func _next_attack() -> StringName:
	var d := distance_to_target()
	if d <= sweep_range and _last_attack != &"sweep":
		return &"sweep"
	var options: Array[StringName] = [&"stomp"]
	if phase >= 2:
		options.append(&"barrage")
		if d >= charge_min_range:
			options.append(&"charge")
	if phase >= 3:
		options.append(&"strike")
	if options.size() > 1:
		options.erase(_last_attack)
	return options[rng.randi() % options.size()]


func _start_attack(attack: StringName) -> void:
	_forced = &""
	_last_attack = attack
	attack_log.append(attack)
	enter_state(StringName(String(attack) + "_windup"))


func _on_enter_state(new_state: StringName) -> void:
	sweep_box.active = new_state == &"sweep"
	charge_box.active = new_state == &"charge"
	var roaring := new_state == &"roar"
	hurt_box.invulnerable = roaring
	vent.invulnerable = roaring
	furnace.invulnerable = roaring
	if new_state != &"strike_windup":
		_antler_mat.emission = Color.BLACK
	match new_state:
		&"sweep":
			GameFeel.shake(0.15)
			Sfx.play(&"swing", get_aim_point(), 6.0)
		&"stomp":
			_stomp()
		&"charge":
			_charge_dir = forward()
			GameFeel.shake(0.15)
			Sfx.play(&"charge", get_aim_point())
		&"recover", &"stunned", &"toppled":
			snap_velocity(Vector3.ZERO)
		&"roar":
			snap_velocity(Vector3.ZERO)
			GameFeel.shake(0.4)
			Sfx.play(&"charge", get_aim_point(), 6.0)
	if new_state == &"toppled":
		expose(toppled_time)
		GameFeel.shake(0.6)
		Sfx.play(&"impact_heavy", global_position)


func _set_phase(p: int) -> void:
	if p == phase:
		return
	phase = p
	var open := phase >= 2
	furnace.set_deferred(&"monitorable", open)
	_grille.visible = not open
	_furnace_mat.albedo_color = FURNACE_COLOR if open else FURNACE_COLOR.darkened(0.4)
	_furnace_mat.emission = FURNACE_COLOR * (1.6 if open else 0.3)
	phase_changed.emit(phase)


func _stomp() -> void:
	var s := Shockwave.spawn(get_parent(), ground_point(global_position))
	s.speed = shockwave_speed
	s.max_radius = shockwave_radius
	s.damage = shockwave_damage
	last_shockwave = s
	GameFeel.shake(0.5)
	Sfx.play(&"impact_heavy", global_position, 4.0)


func _fire_barrage() -> void:
	var centre := lead_target(barrage_flight_time * 0.6)
	var mouth := global_position + Vector3.UP * extents().y * 0.5 + forward() * extents().z * 0.5
	for i: int in barrage_count:
		var p := centre
		if i > 0:
			p += Vector3.FORWARD.rotated(Vector3.UP, TAU * float(i - 1) / float(barrage_count - 1)) * barrage_spread
		LobProjectile.launch(self, mouth, ground_point(p), barrage_flight_time + 0.08 * i, barrage_damage, barrage_radius, FURNACE_COLOR)


func _call_lightning() -> void:
	last_strikes.clear()
	var ahead := lead_target(strike_delay)
	_strike_at(ahead)
	for i: int in strike_count - 1:
		var p := _open_point_near(ahead)
		if p != ahead:
			_strike_at(p)


func _strike_at(p: Vector3) -> void:
	last_strikes.append(DelayedStrike.spawn(get_parent(), ground_point(p), strike_delay, strike_radius, strike_damage))


## A random point 2..strike_scatter m from `centre` in the open from it (never
## past a wall or pillar), or `centre` itself if none turns up in a few tries.
func _open_point_near(centre: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	for _try: int in 6:
		var dir := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized()
		var candidate := centre + dir * rng.randf_range(2.0, strike_scatter)
		var q := PhysicsRayQueryParameters3D.create(centre + Vector3.UP, candidate + Vector3.UP, Layers.WORLD)
		if space.intersect_ray(q).is_empty():
			return candidate
	return centre


func _after_move(_delta: float) -> void:
	if state != &"charge" or state_time < 0.05:
		return
	for i: int in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_collider() is CharacterBody3D:
			continue
		if col.get_normal().dot(_charge_dir) < -0.6:
			GameFeel.shake(0.7)
			Sfx.play(&"impact_heavy", global_position)
			GameFeel.impact(global_position + _charge_dir * extents().z * 0.5 + Vector3.UP * 1.5, ANTLER_COLOR, 3.0, 0.3)
			enter_state(&"stunned")
			return


func _interrupt() -> void:
	super()
	visual.rotation.z = 0.0


func _can_flinch() -> bool:
	return false


func _state_after_flinch() -> StringName:
	return &"stalk"


func _on_death() -> void:
	visual.rotation.z = 0.0
	_furnace_mat.emission = Color.BLACK


## Pawing the ground and tossing its antlers now and then.
func _idle_flavour(_delta: float) -> void:
	var t := fmod(state_time, 4.0)
	var toss := smoothstep(2.6, 3.0, t) * (1.0 - smoothstep(3.3, 3.8, t))
	visual_pitch = 0.12 * toss
	visual_yaw = 0.15 * sin(t * 1.5)
