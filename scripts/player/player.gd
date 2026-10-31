class_name Player
extends CharacterBody3D
## The fox. Third-person movement (run, jump, double jump, dodge), camera-
## relative controls, aim assist and a weapon wheel. All feel numbers live in
## PlayerTuning. Input arrives through an InputProvider so controller,
## keyboard/mouse and scripted test input are interchangeable.
##
## Body: 0.9m wide, 1.8m tall capsule, origin at the feet.

signal weapon_changed(weapon: Weapon)
signal weapon_leveled(weapon: Weapon, level: int)
signal died
signal respawned
signal wheel_toggled(open: bool)

const RADIUS := 0.45
const HEIGHT := 1.8
## Loadout order = weapon wheel order (clockwise from the top) = number keys 1-8.
const DEFAULT_WEAPONS: Array[String] = [
	"res://data/weapons/woodpecker_repeater.tres",
	"res://data/weapons/hornet_swarm.tres",
	"res://data/weapons/salamander_breath.tres",
	"res://data/weapons/owl_lens_rifle.tres",
	"res://data/weapons/kraken_lash.tres",
	"res://data/weapons/pufferfish_mortar.tres",
	"res://data/weapons/galvanic_eel.tres",
	"res://data/weapons/tortoise_sentry.tres",
]
const BODY_COLOR := Color(0.95, 0.45, 0.12)
const RESPAWN_DELAY := 1.5
const KILL_PLANE_Y := -20.0
const WHEEL_SLOWMO := &"weapon_wheel"

@export var tuning: PlayerTuning
@export var weapon_paths: Array[String] = DEFAULT_WEAPONS

## Leave null to read the real controller/keyboard. Tests assign a ScriptedInputProvider.
var input_provider: InputProvider
var input: PlayerInputState = PlayerInputState.new()
var camera_rig: CameraRig
var health: Health
var hurt_box: HurtBox
var visual: Node3D
var muzzle: Node3D
var melee: StaffMelee
var weapons: Array[Weapon] = []
var current_weapon_index: int = 0
var spawn_point: Vector3 = Vector3.ZERO

var aim_target: Node3D = null
var aim_point: Vector3 = Vector3.ZERO
var raw_aim_point: Vector3 = Vector3.ZERO
var aim_direction: Vector3 = Vector3.FORWARD

var facing_yaw: float = 0.0
var is_dead: bool = false
var wheel_open: bool = false
var wheel_highlight: int = 0
var _wheel_cursor: Vector2 = Vector2.ZERO

var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _air_jumps_left: int = 1
var _dodge_time: float = 0.0
var _dodge_cooldown: float = 0.0
var _dodge_dir: Vector3 = Vector3.ZERO
var _air_dodge_used: bool = false
var _dodge_iframes: float = 0.0
var _hurt_iframes: float = 0.0
var _fire_facing: float = 0.0
var _knockback: Vector3 = Vector3.ZERO
var _flash: float = 0.0
var _respawn_timer: float = -1.0
var _body_material: StandardMaterial3D
var _gun_material: StandardMaterial3D


func _ready() -> void:
	if tuning == null:
		tuning = PlayerTuning.new()
	if input_provider == null:
		input_provider = DeviceInputProvider.new()
	add_to_group(&"player")
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.ENEMY
	floor_snap_length = 0.3
	spawn_point = global_position
	facing_yaw = rotation.y
	rotation = Vector3.ZERO

	var cs := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	cs.shape = capsule
	cs.position.y = HEIGHT * 0.5
	add_child(cs)

	_build_visual()

	health = Health.new()
	health.name = "Health"
	health.max_health = tuning.max_health
	add_child(health)
	health.died.connect(_on_died)

	hurt_box = HurtBox.new()
	hurt_box.name = "HurtBox"
	hurt_box.collision_layer = Layers.PLAYER_HURTBOX
	hurt_box.health = health
	var hcs := CollisionShape3D.new()
	hcs.shape = capsule
	hcs.position.y = HEIGHT * 0.5
	hurt_box.add_child(hcs)
	add_child(hurt_box)
	hurt_box.hurt.connect(_on_hurt)

	camera_rig = CameraRig.new()
	camera_rig.name = "CameraRig"
	camera_rig.target = self
	camera_rig.tuning = tuning
	camera_rig.yaw = facing_yaw
	add_child(camera_rig)
	if camera_rig.spring != null:
		camera_rig.spring.add_excluded_object(get_rid())

	for path: String in weapon_paths:
		var d := load(path) as WeaponData
		if d == null or d.weapon_script == null:
			push_error("Player: could not load weapon %s" % path)
			continue
		var w := d.weapon_script.new() as Weapon
		w.setup(d, self)
		muzzle.add_child(w)
		w.leveled_up.connect(_on_weapon_leveled.bind(w))
		weapons.append(w)
	_select_weapon(0, true)


func _build_visual() -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = BODY_COLOR
	_body_material.emission_enabled = true
	_body_material.emission = Color.BLACK

	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = RADIUS
	cap.height = HEIGHT
	body.mesh = cap
	body.material_override = _body_material
	body.position.y = HEIGHT * 0.5
	visual.add_child(body)

	# Snout, ears and tail so facing is obvious from any angle.
	var white := _flat_material(Color(0.95, 0.92, 0.85))
	_add_box(Vector3(0.3, 0.22, 0.35), Vector3(0, 1.45, -0.5), white)
	_add_box(Vector3(0.14, 0.3, 0.1), Vector3(-0.22, 1.9, -0.05), _body_material)
	_add_box(Vector3(0.14, 0.3, 0.1), Vector3(0.22, 1.9, -0.05), _body_material)
	var tail := _add_box(Vector3(0.22, 0.22, 0.7), Vector3(0, 0.6, 0.65), white)
	tail.rotation.x = -0.5

	muzzle = Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.45, 1.2, -0.55)
	visual.add_child(muzzle)
	_gun_material = _flat_material(Color.WHITE)
	_add_box(Vector3(0.16, 0.16, 0.5), Vector3(0.45, 1.2, -0.3), _gun_material)

	melee = StaffMelee.new()
	melee.tuning = tuning
	visual.add_child(melee)


func _add_box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	visual.add_child(mi)
	return mi


func _flat_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _unhandled_input(event: InputEvent) -> void:
	var device := input_provider as DeviceInputProvider
	if device == null:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		device.add_mouse_motion((event as InputEventMouseMotion).relative)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if is_dead:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			respawn()
		camera_rig.follow(delta)
		return

	input_provider.poll(input, delta)
	_update_timers(delta)
	_update_wheel()
	if not wheel_open:
		camera_rig.apply_look(input, delta)
	_handle_weapon_switch()
	_update_camera_mode()
	_update_aim()
	_handle_melee(delta)
	_move(delta)
	_handle_fire()
	_update_facing(delta)
	camera_rig.follow(delta)
	_update_visuals(delta)
	if global_position.y < KILL_PLANE_Y:
		respawn()


func _update_timers(delta: float) -> void:
	_coyote = maxf(0.0, _coyote - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_dodge_time = maxf(0.0, _dodge_time - delta)
	_dodge_cooldown = maxf(0.0, _dodge_cooldown - delta)
	_dodge_iframes = maxf(0.0, _dodge_iframes - delta)
	_hurt_iframes = maxf(0.0, _hurt_iframes - delta)
	_fire_facing = maxf(0.0, _fire_facing - delta)
	_flash = maxf(0.0, _flash - delta * 6.0)
	hurt_box.invulnerable = is_invulnerable()
	if input.jump_pressed:
		_jump_buffer = tuning.jump_buffer_time


# --- Movement -----------------------------------------------------------------

func _move(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		_coyote = tuning.coyote_time
		_air_jumps_left = 1
		_air_dodge_used = false

	var wish := camera_relative(input.move)

	# Melee can be interrupted by dodge (always) or jump (after the hit lands).
	if melee.is_busy() and melee.can_cancel():
		var after_hit := melee.phase != StaffMelee.Phase.SWING or melee.phase_time > tuning.melee_active_end
		if input.dodge_pressed or (_jump_buffer > 0.0 and after_hit):
			melee.cancel()

	# Dodge
	if input.dodge_pressed and not melee.is_busy() and _dodge_cooldown <= 0.0 and _dodge_time <= 0.0 and (on_floor or not _air_dodge_used):
		_dodge_dir = wish.normalized() if wish.length_squared() > 0.01 else facing_forward()
		_dodge_time = tuning.dodge_duration
		_dodge_cooldown = tuning.dodge_duration + tuning.dodge_cooldown
		_dodge_iframes = tuning.dodge_iframes
		if not on_floor:
			_air_dodge_used = true
			velocity.y = maxf(velocity.y, 0.0)

	# Horizontal
	var h := Vector3(velocity.x, 0.0, velocity.z) - _knockback
	if is_dodging():
		h = _dodge_dir * tuning.dodge_speed
	elif melee.phase == StaffMelee.Phase.SWING:
		if melee.phase_time < tuning.melee_lunge_time:
			h = facing_forward() * tuning.melee_lunge_speed
		else:
			h = h.move_toward(Vector3.ZERO, tuning.ground_deceleration * delta)
	elif melee.phase == StaffMelee.Phase.SLAM_HOVER or melee.phase == StaffMelee.Phase.SLAM_FALL:
		h = Vector3.ZERO
	elif melee.phase == StaffMelee.Phase.POUNCE:
		pass  # keep the launch momentum
	elif melee.phase == StaffMelee.Phase.SLAM_RECOVER:
		h = h.move_toward(Vector3.ZERO, tuning.ground_deceleration * delta)
	else:
		var target_h := wish * move_speed_for(wish)
		var accel: float
		if not on_floor:
			accel = tuning.air_acceleration
		elif wish.length_squared() > 0.0001:
			accel = tuning.ground_acceleration
		else:
			accel = tuning.ground_deceleration
		h = h.move_toward(target_h, accel * delta)
	_knockback = _knockback.move_toward(Vector3.ZERO, 30.0 * delta)
	h += _knockback

	# Jump
	if _jump_buffer > 0.0 and not melee.is_busy():
		if on_floor or _coyote > 0.0:
			velocity.y = tuning.jump_velocity()
			_jump_buffer = 0.0
			_coyote = 0.0
		elif _air_jumps_left > 0:
			velocity.y = tuning.double_jump_velocity()
			_air_jumps_left -= 1
			_jump_buffer = 0.0

	# Gravity (none during an air dodge so it reads as a dash; slams set it directly)
	if melee.phase == StaffMelee.Phase.SLAM_HOVER:
		velocity.y = 0.0
	elif melee.phase == StaffMelee.Phase.SLAM_FALL:
		velocity.y = -tuning.slam_fall_speed
	elif not (is_dodging() and not on_floor):
		var g := tuning.gravity
		if velocity.y < 0.0:
			g *= tuning.fall_gravity_multiplier
		elif not input.jump_held:
			g *= tuning.jump_release_gravity_multiplier
		velocity.y = maxf(velocity.y - g * delta, -tuning.max_fall_speed)

	velocity.x = h.x
	velocity.z = h.z
	move_and_slide()
	if is_on_floor() and (melee.phase == StaffMelee.Phase.SLAM_FALL or melee.phase == StaffMelee.Phase.POUNCE):
		melee.land(global_position)


# --- Melee --------------------------------------------------------------------

func _handle_melee(delta: float) -> void:
	if input.melee_pressed and not is_dodging() and not wheel_open:
		var stick := camera_relative(input.move)
		var started := melee.request_attack(is_on_floor(), stick)
		match started:
			StaffMelee.Phase.SWING:
				_snap_facing_for_swing(stick)
			StaffMelee.Phase.POUNCE:
				var dir := stick.normalized()
				facing_yaw = yaw_of(dir)
				velocity = dir * tuning.pounce_speed + Vector3.UP * tuning.pounce_up_speed
	# A buffered press chains into the next swing inside update(); re-aim it too.
	var before := melee.combo_index
	melee.update(delta)
	if melee.phase == StaffMelee.Phase.SWING and melee.combo_index != before and melee.phase_time == 0.0:
		_snap_facing_for_swing(camera_relative(input.move))


## Turn toward the closest enemy near the stick direction (or facing), so swings connect.
func _snap_facing_for_swing(stick: Vector3) -> void:
	var reference := stick.normalized() if stick.length_squared() > 0.04 else facing_forward()
	var best: Node3D = null
	var best_dist := tuning.melee_snap_range
	for n: Node3D in AimAssist.nodes_in_group(get_tree(), &"enemies"):
		var to := n.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		if dist < 0.01 or dist > best_dist:
			continue
		if rad_to_deg(reference.angle_to(to / dist)) > tuning.melee_snap_angle_deg:
			continue
		best = n
		best_dist = dist
	if best != null:
		facing_yaw = yaw_of(best.global_position - global_position)
	elif stick.length_squared() > 0.04:
		facing_yaw = yaw_of(stick)
	visual.rotation.y = facing_yaw


## Top speed for a wish direction: full run, strafe (slower, slowest backwards) or scoped.
func move_speed_for(wish: Vector3) -> float:
	if is_zoomed():
		return tuning.run_speed * tuning.zoom_move_multiplier
	if not is_strafing():
		return tuning.run_speed
	var speed := tuning.run_speed * tuning.strafe_speed_multiplier
	if wish.length_squared() > 0.0001:
		var backwards := maxf(0.0, -wish.normalized().dot(camera_forward()))
		speed *= lerpf(1.0, tuning.strafe_backpedal_multiplier, backwards)
	return speed


func is_strafing() -> bool:
	return input.strafe_held and not is_dead


## Strafe with a scoped weapon (WeaponData.zoom_fov > 0) looks down the scope.
func is_zoomed() -> bool:
	var w := current_weapon()
	return is_strafing() and w != null and w.data.zoom_fov > 0.0


func camera_forward() -> Vector3:
	return Vector3(-sin(camera_rig.yaw), 0.0, -cos(camera_rig.yaw))


func _update_camera_mode() -> void:
	if is_zoomed():
		camera_rig.set_view(tuning.zoom_camera_distance, current_weapon().data.zoom_fov, tuning.zoom_shoulder_offset)
	elif is_strafing():
		camera_rig.set_view(tuning.strafe_camera_distance, tuning.camera_fov, 0.0)
	else:
		camera_rig.set_view(tuning.camera_distance, tuning.camera_fov, 0.0)


## Converts a stick/WASD vector into a world direction relative to the camera.
func camera_relative(move: Vector2) -> Vector3:
	var wish := Basis(Vector3.UP, camera_rig.yaw) * Vector3(move.x, 0.0, move.y)
	return wish.normalized() if wish.length() > 1.0 else wish


func _update_facing(delta: float) -> void:
	var target_yaw := facing_yaw
	var speed := deg_to_rad(tuning.turn_speed_deg)
	if melee.is_busy():
		pass  # facing is set when the attack starts
	elif is_strafing():
		# Lock to the camera, not the aim target, so strafing never jitters
		# when aim assist swaps targets.
		target_yaw = camera_rig.yaw
		speed = deg_to_rad(tuning.fire_turn_speed_deg)
	elif _fire_facing > 0.0:
		target_yaw = yaw_of(aim_direction)
		speed = deg_to_rad(tuning.fire_turn_speed_deg)
	elif is_dodging():
		target_yaw = yaw_of(_dodge_dir)
	else:
		var h := Vector3(velocity.x, 0.0, velocity.z)
		if h.length() > 0.5 and input.move.length() > 0.1:
			target_yaw = yaw_of(h)
	facing_yaw = rotate_toward(facing_yaw, target_yaw, speed * delta)
	visual.rotation.y = facing_yaw


static func yaw_of(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


func facing_forward() -> Vector3:
	return Vector3(-sin(facing_yaw), 0.0, -cos(facing_yaw))


func is_dodging() -> bool:
	return _dodge_time > 0.0


func is_invulnerable() -> bool:
	return _dodge_iframes > 0.0 or _hurt_iframes > 0.0


# --- Aim and weapons ----------------------------------------------------------

func _update_aim() -> void:
	var origin := camera_rig.get_aim_origin()
	var dir := camera_rig.get_aim_direction()
	# Start near the player so nothing between camera and fox is targeted.
	var start := origin + dir * (camera_rig.spring.spring_length * 0.8)
	var far := start + dir * tuning.aim_max_range
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(start, far, Layers.WORLD | Layers.ENEMY_HURTBOX)
	q.collide_with_areas = true
	var hit := space.intersect_ray(q)
	raw_aim_point = far if hit.is_empty() else (hit["position"] as Vector3)
	aim_point = raw_aim_point
	aim_target = null
	var w := current_weapon()
	if w == null or w.data.uses_aim_assist:
		var angle := tuning.zoom_aim_assist_angle_deg if is_zoomed() else tuning.aim_assist_angle_deg
		aim_target = AimAssist.pick_target(start, dir, AimAssist.nodes_in_group(get_tree(), &"aim_targets"),
				angle, tuning.aim_max_range, space, muzzle.global_position)
	if aim_target != null:
		aim_point = AimAssist.get_aim_point(aim_target)
	var to := aim_point - muzzle.global_position
	aim_direction = to.normalized() if to.length() > 0.5 else dir


func current_aim() -> AimInfo:
	var aim := AimInfo.create(muzzle.global_position, aim_direction, aim_target)
	aim.point = aim_point
	aim.raw_point = raw_aim_point
	return aim


func _handle_fire() -> void:
	var w := current_weapon()
	if w == null:
		return
	var firing := input.fire_held and not is_dodging() and not melee.is_busy() and not wheel_open
	if firing:
		_fire_facing = tuning.fire_facing_time
	w.trigger(firing, current_aim())


## Hold the wheel button: time slows, the right stick (or mouse) highlights a
## slot, releasing equips it. Movement still works (slowed); camera, firing
## and melee are paused while it is open.
func _update_wheel() -> void:
	if input.wheel_held and not wheel_open and not weapons.is_empty():
		wheel_open = true
		wheel_highlight = current_weapon_index
		_wheel_cursor = Vector2.ZERO
		GameFeel.set_slowmo(WHEEL_SLOWMO, tuning.wheel_time_scale)
		wheel_toggled.emit(true)
	elif not input.wheel_held and wheel_open:
		close_wheel(true)
	if not wheel_open:
		return
	_wheel_cursor = (_wheel_cursor + input.mouse_look).limit_length(tuning.wheel_mouse_threshold * 3.0)
	if input.look.length() >= tuning.wheel_stick_threshold:
		wheel_highlight = WeaponWheel.index_for_direction(input.look, weapons.size())
	elif _wheel_cursor.length() >= tuning.wheel_mouse_threshold:
		wheel_highlight = WeaponWheel.index_for_direction(_wheel_cursor, weapons.size())


func close_wheel(equip: bool) -> void:
	if not wheel_open:
		return
	wheel_open = false
	GameFeel.clear_slowmo(WHEEL_SLOWMO)
	if equip:
		_select_weapon(wheel_highlight)
	wheel_toggled.emit(false)


func _exit_tree() -> void:
	# Never leave the game in slow motion if the player is removed (scene restart).
	GameFeel.clear_slowmo(WHEEL_SLOWMO)


func _handle_weapon_switch() -> void:
	if weapons.is_empty():
		return
	if input.weapon_slot >= 0 and input.weapon_slot < weapons.size():
		_select_weapon(input.weapon_slot)
	elif input.weapon_next:
		_select_weapon((current_weapon_index + 1) % weapons.size())
	elif input.weapon_prev:
		_select_weapon((current_weapon_index - 1 + weapons.size()) % weapons.size())


func _select_weapon(index: int, force: bool = false) -> void:
	if weapons.is_empty() or (index == current_weapon_index and not force):
		return
	var old := current_weapon()
	if old != null:
		old.on_unequipped()
	current_weapon_index = index
	for other: Weapon in weapons:
		other.visible = other == weapons[index]
	var w := current_weapon()
	_gun_material.albedo_color = w.data.color
	weapon_changed.emit(w)


func current_weapon() -> Weapon:
	if current_weapon_index < 0 or current_weapon_index >= weapons.size():
		return null
	return weapons[current_weapon_index]


func refill_ammo_fraction(fraction: float) -> void:
	for w: Weapon in weapons:
		w.add_ammo(ceili(w.max_ammo() * fraction))


func debug_level_current_weapon() -> void:
	var w := current_weapon()
	if w != null and not w.is_max_level():
		w.add_xp(w.xp_needed() - w.xp)


func _on_weapon_leveled(level: int, w: Weapon) -> void:
	GameFeel.impact(global_position + Vector3.UP, w.data.color, 3.0, 0.4)
	weapon_leveled.emit(w, level)


# --- Damage -------------------------------------------------------------------

func get_aim_point() -> Vector3:
	return global_position + Vector3.UP * HEIGHT * 0.55


func _on_hurt(info: DamageInfo) -> void:
	if info.is_dot:
		return
	_hurt_iframes = tuning.hurt_iframes
	hurt_box.invulnerable = true
	var away := global_position - info.source_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = -facing_forward()
	_knockback = away.normalized() * info.knockback * tuning.hurt_knockback_scale
	velocity.y = maxf(velocity.y, info.knockback_up)
	_flash = 1.0
	GameFeel.shake(0.5)
	GameFeel.hit_stop(0.05)


func _on_died(_info: DamageInfo) -> void:
	is_dead = true
	_respawn_timer = RESPAWN_DELAY
	velocity = Vector3.ZERO
	current_weapon().on_unequipped()
	melee.cancel()
	close_wheel(false)
	visual.visible = false
	GameFeel.impact(global_position + Vector3.UP, BODY_COLOR, 3.0, 0.5)
	died.emit()


func respawn() -> void:
	is_dead = false
	global_position = spawn_point
	velocity = Vector3.ZERO
	_knockback = Vector3.ZERO
	health.reset()
	_hurt_iframes = tuning.hurt_iframes
	visual.visible = true
	camera_rig.snap_to_target()
	respawned.emit()


func _update_visuals(_delta: float) -> void:
	_body_material.emission = Color(1.0, 0.1, 0.1) * _flash
	# Blink during hurt i-frames (not dodge i-frames: dodging should look clean).
	visual.visible = _hurt_iframes <= 0.0 or fmod(_hurt_iframes, 0.12) > 0.05
	# Hide the fox once the scope is mostly zoomed in; at that FOV it fills the frame.
	if is_zoomed() and camera_rig.camera.fov < tuning.camera_fov * 0.6:
		visual.visible = false
