class_name BrassPangolin
extends Enemy
## Brass Pangolin: an armoured advancer you have to work around.
## Its front plates turn most damage aside (the `guard_arc_deg` cone around its
## facing), and it turns slowly, so flanking, lobbing shots behind it and DoT all
## beat the armour. Pattern: advance (guarded) -> volley windup (plates flare)
## -> fan of scale shards -> recover. Up close: curl (glows, squashes) -> roll at
## the target, steering a little and bouncing off walls -> dizzy: flipped on its
## back with the armour down and the belly weak spot open. A roll that hits the
## player skips the dizzy (it uncurls guarded), so dodging the roll is the payoff.

const ARMOUR_COLOR := Color(0.95, 0.85, 0.5)
const BELLY_COLOR := Color(0.95, 0.86, 0.72)
## Same orange as the bull's boiler: the weak-spot colour.
const BELLY_GLOW := Color(1.0, 0.45, 0.1)

@export_group("Armour")
## Full width of the guarded cone in front (the roll guards all round).
@export var guard_arc_deg: float = 120.0
## Damage multiplier for hits the armour turns aside.
@export var armour_factor: float = 0.15
@export var belly_multiplier: float = 2.0
@export_group("Advance")
@export var advance_stop_range: float = 7.0
@export_group("Volley")
@export var volley_range: float = 15.0
@export var volley_cooldown: float = 2.4
@export var volley_windup_time: float = 0.7
## Stop turning this long before the volley so a sidestep reads.
@export var volley_lock_time: float = 0.2
@export var volley_recover_time: float = 0.6
@export var shard_count: int = 5
@export var shard_spread_deg: float = 40.0
@export var shard_speed: float = 15.0
@export var shard_damage: float = 8.0
@export_group("Roll")
@export var roll_trigger_range: float = 6.0
@export var roll_cooldown: float = 4.0
@export var curl_time: float = 0.6
@export var roll_speed: float = 13.0
@export var roll_turn_deg: float = 70.0
@export var roll_max_time: float = 2.4
## Walls it bounces off before the next one knocks it dizzy.
@export var roll_bounces: int = 2
@export var roll_damage: float = 20.0
@export var roll_knockback: float = 12.0
@export var uncurl_time: float = 0.8
@export var dizzy_time: float = 2.0

var roll_box: HitBox
var belly: HurtBox
var bounces: int = 0
var volley_count: int = 0
var blocked_hits: int = 0
var _roll_dir: Vector3 = Vector3.FORWARD
## Starts ready: a pangolin that meets you up close rolls at once.
var _since_roll: float = INF
var _ball: MeshInstance3D
var _belly_mesh: MeshInstance3D
var _belly_mat: StandardMaterial3D
var _plates: Node3D
var _shell_parts: Array[Node3D] = []


func _init() -> void:
	display_name = "Brass Pangolin"
	body_shape = BodyShape.BOX
	body_size = Vector3(1.3, 1.1, 2.0)
	color = Color(0.38, 0.62, 0.55)
	max_health = 120.0
	move_speed = 3.0
	acceleration = 18.0
	turn_speed_deg = 100.0
	xp_value = 35
	knockback_resistance = 0.7
	status_resistance = 0.7
	sight_range = 20.0
	notice_time = 1.4


func _setup() -> void:
	var e := extents()
	for c: Node in visual.get_children():
		if c is MeshInstance3D and c != ice_block:
			_shell_parts.append(c as Node3D)
	# Overlapping back scales, then the front plate fan that does the guarding.
	for i: int in 3:
		var z := e.z * (0.3 - 0.3 * i)
		_shell_parts.append(add_visual_box(Vector3(e.x + 0.12, 0.18, e.z * 0.34), Vector3(0, e.y + 0.05 - 0.06 * i, z), ARMOUR_COLOR.darkened(0.15 * i)))
	# Stubby legs and a pale belly: barely seen upright, obvious when it is
	# flipped on its back (dizzy).
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_shell_parts.append(add_visual_box(Vector3(0.2, 0.3, 0.24), Vector3(sx * (e.x * 0.5 + 0.06), 0.12, sz * e.z * 0.3), color.darkened(0.5)))
	_belly_mesh = add_visual_box(Vector3(e.x * 0.8, 0.08, e.z * 0.75), Vector3(0, -0.02, 0), BELLY_COLOR)
	_belly_mat = _belly_mesh.material_override as StandardMaterial3D
	_belly_mat.emission_enabled = true
	_shell_parts.append(_belly_mesh)
	_plates = Node3D.new()
	_plates.position = Vector3(0, e.y * 0.15, -e.z * 0.5 - 0.15)
	visual.add_child(_plates)
	_shell_parts.append(_plates)
	for i: int in 3:
		var plate := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(e.x * 0.55, e.y * 0.85, 0.1)
		plate.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = ARMOUR_COLOR
		mat.metallic = 0.6
		mat.roughness = 0.35
		plate.material_override = mat
		plate.position = Vector3((i - 1) * e.x * 0.36, e.y * 0.42, 0.04 * absf(i - 1))
		plate.rotation.y = -(i - 1) * 0.35
		_plates.add_child(plate)
	# Curled ball, shown while curling and rolling.
	_ball = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = e.y * 0.62
	sphere.height = e.y * 1.24
	_ball.mesh = sphere
	var ball_mat := StandardMaterial3D.new()
	ball_mat.albedo_color = ARMOUR_COLOR.darkened(0.1)
	ball_mat.metallic = 0.6
	ball_mat.roughness = 0.35
	_ball.material_override = ball_mat
	_ball.position.y = e.y * 0.6
	_ball.visible = false
	visual.add_child(_ball)
	for i: int in 4:
		var band := add_visual_box(Vector3(e.y * 1.27, 0.08, 0.2), Vector3.ZERO, ARMOUR_COLOR.darkened(0.4))
		visual.remove_child(band)
		_ball.add_child(band)
		band.rotation.x = PI * 0.25 * i

	# Reaches past the body box (which stays put while curled) so the ball hits
	# before the body bumps into the target.
	roll_box = make_hit_box("RollHitBox", Vector3(e.x + 0.5, e.y, e.z + 0.5), Vector3(0, e.y * 0.5, 0), roll_damage, roll_knockback, 5.0)
	roll_box.hit_stop = 0.05
	roll_box.hit_landed.connect(_on_roll_hit)
	# Wraps the whole body so precise shots crit it while dizzy (area hits still
	# prefer the plain hurtbox).
	belly = make_weak_spot(e + Vector3.ONE * 0.1, Vector3(0, e.y * 0.5, 0), belly_multiplier)
	belly.name = "Belly"
	belly.set_deferred(&"monitorable", false)


## The armour is up unless it is dizzy or disabled (frozen, staggered).
func is_guarding() -> bool:
	return state != &"dizzy" and not is_disabled() and not health.is_dead


## Whether a hit coming from `from` lands on the armour.
func blocks_from(from: Vector3) -> bool:
	if not is_guarding():
		return false
	if state == &"curl" or state == &"roll":
		return true
	var to := from - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return false
	return rad_to_deg(forward().angle_to(to.normalized())) <= guard_arc_deg * 0.5


func _modify_incoming(info: DamageInfo) -> void:
	super(info)
	if info.is_dot or not blocks_from(info.source_position):
		return
	info.amount *= armour_factor
	info.knockback *= 0.3
	info.is_critical = false
	blocked_hits += 1
	var to := info.source_position - global_position
	to.y = 0.0
	GameFeel.impact(get_aim_point() + to.normalized() * extents().z * 0.5, ARMOUR_COLOR, 0.6, 0.12)


func _physics_process(delta: float) -> void:
	_since_roll += delta
	super(delta)


func _tick_state(delta: float) -> void:
	match state:
		&"idle":
			desired_velocity = Vector3.ZERO
			if has_target():
				enter_state(&"advance")
		&"advance":
			face_toward(target_position(), delta)
			var d := distance_to_target()
			desired_velocity = forward() * move_speed if d > advance_stop_range else Vector3.ZERO
			if d <= roll_trigger_range and _since_roll >= roll_cooldown:
				enter_state(&"curl")
			elif state_time >= volley_cooldown and d <= volley_range:
				enter_state(&"volley_windup")
		&"volley_windup":
			desired_velocity = Vector3.ZERO
			if state_time < volley_windup_time - volley_lock_time:
				face_toward(target_position(), delta)
			var t := clampf(state_time / volley_windup_time, 0.0, 1.0)
			telegraph = t
			_plates.scale = Vector3.ONE * (1.0 + 0.35 * t)
			if state_time >= volley_windup_time:
				_fire_volley()
				enter_state(&"volley_recover")
		&"volley_recover":
			desired_velocity = Vector3.ZERO
			if state_time >= volley_recover_time:
				enter_state(&"advance")
		&"curl":
			desired_velocity = Vector3.ZERO
			face_toward(target_position(), delta)
			var t := clampf(state_time / curl_time, 0.0, 1.0)
			telegraph = t
			visual_scale = Vector3(1.0, 1.0 - 0.15 * t, 1.0 - 0.15 * t)
			if state_time >= curl_time:
				enter_state(&"roll")
		&"roll":
			if has_target():
				var want := direction_to_target()
				var angle := _roll_dir.signed_angle_to(want, Vector3.UP)
				var step := deg_to_rad(roll_turn_deg) * delta
				_roll_dir = _roll_dir.rotated(Vector3.UP, clampf(angle, -step, step)).normalized()
				rotation.y = atan2(-_roll_dir.x, -_roll_dir.z)
			snap_velocity(_roll_dir * roll_speed)
			_ball.rotation.x = -state_time * roll_speed / (extents().y * 0.62)
			if state_time >= roll_max_time:
				enter_state(&"dizzy")
		&"uncurl":
			desired_velocity = Vector3.ZERO
			if state_time >= uncurl_time:
				enter_state(&"advance")
		&"dizzy":
			desired_velocity = Vector3.ZERO
			# On its back, legs up, wobbling; the open belly pulses.
			visual.rotation.z = PI + sin(state_time * 14.0) * 0.12
			visual_offset = Vector3.UP * extents().y
			_belly_mat.emission = BELLY_GLOW * (0.45 + 0.25 * sin(state_time * 9.0))
			if state_time >= dizzy_time:
				enter_state(&"advance")


func _on_enter_state(new_state: StringName) -> void:
	var curled := new_state == &"curl" or new_state == &"roll"
	roll_box.active = new_state == &"roll"
	_ball.visible = curled
	for part: Node3D in _shell_parts:
		part.visible = not curled
	_plates.scale = Vector3.ONE
	if new_state != &"dizzy":
		visual.rotation.z = 0.0
		_belly_mat.emission = Color.BLACK
	belly.set_deferred(&"monitorable", new_state == &"dizzy")
	match new_state:
		&"roll":
			_roll_dir = forward()
			bounces = 0
			_since_roll = 0.0
			GameFeel.shake(0.1)
		&"uncurl", &"dizzy":
			snap_velocity(Vector3.ZERO)
	if new_state == &"dizzy":
		GameFeel.impact(get_aim_point(), ARMOUR_COLOR, 1.6, 0.2)


func _after_move(_delta: float) -> void:
	if state != &"roll" or state_time < 0.05:
		return
	for i: int in get_slide_collision_count():
		var col := get_slide_collision(i)
		if col.get_collider() is CharacterBody3D:
			continue
		var n := col.get_normal()
		n.y = 0.0
		if n.length_squared() < 0.01 or n.normalized().dot(_roll_dir) > -0.3:
			continue
		n = n.normalized()
		GameFeel.impact(global_position + Vector3.UP * extents().y * 0.6 - n * extents().y * 0.5, ARMOUR_COLOR, 1.4, 0.2)
		if bounces >= roll_bounces:
			GameFeel.shake(0.4)
			enter_state(&"dizzy")
			return
		bounces += 1
		GameFeel.shake(0.2)
		_roll_dir = _roll_dir.bounce(n).normalized()
		rotation.y = atan2(-_roll_dir.x, -_roll_dir.z)
		snap_velocity(_roll_dir * roll_speed)
		return


func _on_roll_hit(_hb: HurtBox, _info: DamageInfo) -> void:
	if state == &"roll":
		enter_state(&"uncurl")


## Directions of the volley's shards (flat, fanned around the facing).
func shard_directions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i: int in shard_count:
		var u := 0.0 if shard_count <= 1 else float(i) / float(shard_count - 1) - 0.5
		out.append(forward().rotated(Vector3.UP, deg_to_rad(shard_spread_deg) * u))
	return out


func _fire_volley() -> void:
	volley_count += 1
	var mouth := global_position + Vector3.UP * extents().y * 0.6 + forward() * (extents().z * 0.5 + 0.3)
	for dir: Vector3 in shard_directions():
		ScaleShard.launch(self, mouth, dir, shard_speed, shard_damage)
	_plates.scale = Vector3.ONE * 0.85


func _interrupt() -> void:
	super()
	visual.rotation.z = 0.0


func _state_after_flinch() -> StringName:
	return &"advance"


func _can_flinch() -> bool:
	return false


func _on_death() -> void:
	visual.rotation.z = 0.0
	_ball.visible = false
	for part: Node3D in _shell_parts:
		part.visible = true


## Rooting about: the snout sweeps side to side, low, like it is sniffing for ants.
func _idle_flavour(_delta: float) -> void:
	var t := fmod(state_time, 2.6)
	var sniff := smoothstep(0.2, 0.6, t) * (1.0 - smoothstep(1.8, 2.3, t))
	visual_pitch = -0.12 * sniff
	visual_yaw = 0.25 * sin(t * 4.0) * sniff
