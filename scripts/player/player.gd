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
## A staff hit landed a Burrow Claws sneak attack (bonus damage) on `enemy`.
signal sneak_attacked(enemy: Enemy)

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
	# Page 2: status, utility and anti-armour weapons
	"res://data/weapons/frost_narwhal.tres",
	"res://data/weapons/viper_spitter.tres",
	"res://data/weapons/silk_launcher.tres",
	"res://data/weapons/echo_horn.tres",
	"res://data/weapons/moth_lantern.tres",
	"res://data/weapons/hermit_bulwark.tres",
	"res://data/weapons/clockwork_swallow.tres",
	"res://data/weapons/rhino_beetle_ram.tres",
]
const BODY_COLOR := Color(0.95, 0.45, 0.12)
const RESPAWN_DELAY := 1.5
const KILL_PLANE_Y := -20.0
const WHEEL_SLOWMO := &"weapon_wheel"
const WHEEL_PAGE_SIZE := 8

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
## Brass Grapple-Tail (gadget &"grapple"): ring targeting, reel and rope.
var grapple: GrappleTail
## Leaf-wing Cloak (gadget &"glide"): glide state, steering and the wings.
var cloak: LeafCloak
## Burrow Claws (gadget &"burrow"): dig into soil patches, tunnel, pop out.
var burrow: BurrowClaws
## Copper Conduit Gauntlet (gadget &"conduit"): staff a live barrier to charge, a terminal to power.
var conduit: ConduitGauntlet
var weapons: Array[Weapon] = []
var current_weapon_index: int = 0
var spawn_point: Vector3 = Vector3.ZERO
## Facing (yaw) after a respawn; checkpoints set it with spawn_point.
var spawn_yaw: float = 0.0
## Unlocked traversal gadgets (has_gadget / unlock_gadget).
var gadgets: Gadgets = Gadgets.new()

var aim_target: Node3D = null
var aim_point: Vector3 = Vector3.ZERO
var raw_aim_point: Vector3 = Vector3.ZERO
var aim_direction: Vector3 = Vector3.FORWARD

var facing_yaw: float = 0.0
var is_dead: bool = false
var wheel_open: bool = false
var wheel_highlight: int = 0
## Page of WHEEL_PAGE_SIZE weapons shown on the wheel; number keys use it too.
var wheel_page: int = 0
var _wheel_cursor: Vector2 = Vector2.ZERO
## Highlight the wheel last ticked for (a tick sounds on each change).
var _wheel_heard: int = -1

var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _air_jumps_left: int = 1
var _dodge_time: float = 0.0
var _dodge_cooldown: float = 0.0
var _dodge_dir: Vector3 = Vector3.ZERO
var _air_dodge_used: bool = false
var _dodge_iframes: float = 0.0
var _hurt_iframes: float = 0.0
## Rising from launch_up(): releasing jump must not cut the arc short.
var _launched: bool = false
## Rising from a grapple release or burrow pop-out hop: releasing jump must not cut it short
## (unlike _launched, jumps and grapples stay allowed).
var _gadget_hop: bool = false
## After a grapple release: reduced air control so holding forward does not
## carry the fox off the small ledge it was reeled onto.
var _grapple_settle: float = 0.0
## Set when the cloak is forced shut (dodge, grapple, hit): it stays shut until
## jump is released and held again.
var _glide_needs_press: bool = false
## Seconds left in which the next staff swing hit is a sneak attack (after popping out).
var _sneak_left: float = 0.0
## A sneak hit landed this frame: the window closes on the next tick.
var _sneak_spent: bool = false
## Seconds left after popping out during which enemies still can't see the fox.
var _conceal_left: float = 0.0
## In the air from a pop-out hop: a staff press waits for the landing (a swing,
## not a slam), so a sneak attack is one press.
var _burrow_hop: bool = false
var _melee_after_hop: bool = false
var _fire_facing: float = 0.0
var _knockback: Vector3 = Vector3.ZERO
var _flash: float = 0.0
var _respawn_timer: float = -1.0
var fox_model: FoxModel
var _gun_material: StandardMaterial3D
## The hand-held gun (hidden while the staff is drawn).
var _gun: MeshInstance3D


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
	spawn_yaw = facing_yaw
	rotation = Vector3.ZERO

	var cs := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	cs.shape = capsule
	cs.position.y = HEIGHT * 0.5
	add_child(cs)

	_build_visual()
	melee.hit_box.damage_modifier = _sneak_modifier
	melee.swung.connect(func(index: int) -> void:
		var times := tuning.melee_swing_time
		fox_model.play_swing(index, melee.combo_length(), times[mini(index, times.size() - 1)]))
	melee.hit_box.hit_landed.connect(_on_staff_hit)
	melee.slam_box.hit_landed.connect(_on_staff_hit)
	melee.hit_box.hit_landed.connect(conduit.on_staff_hit)
	_connect_feedback()

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
	fox_model = FoxModel.new(HEIGHT, tuning)
	visual.add_child(fox_model)

	muzzle = Node3D.new()
	muzzle.name = "Muzzle"
	# Where the hand-held gun's tip sits with the arm raised to aim (FoxModel aim pose).
	muzzle.position = Vector3(0.21, 0.96, -0.85)
	visual.add_child(muzzle)
	_gun_material = _flat_material(Color.WHITE)
	# The gun sits in the fox's right hand and points wherever the arm does.
	_gun = MeshInstance3D.new()
	var gun_box := BoxMesh.new()
	gun_box.size = Vector3(0.13, 0.13, 0.42)
	_gun.mesh = gun_box
	_gun.material_override = _gun_material
	_gun.position = Vector3(0, 0.03, -0.12)
	fox_model.gun_mount.add_child(_gun)

	melee = StaffMelee.new()
	melee.tuning = tuning
	visual.add_child(melee)
	# The staff rides in the hand while attacking, slung on the back otherwise.
	melee.hand_mount = fox_model.staff_hand_mount
	melee.back_mount = fox_model.staff_back_mount

	grapple = GrappleTail.new()
	grapple.player = self
	grapple.tuning = tuning
	add_child(grapple)

	cloak = LeafCloak.new()
	cloak.player = self
	cloak.tuning = tuning
	visual.add_child(cloak)

	burrow = BurrowClaws.new()
	burrow.player = self
	burrow.tuning = tuning
	add_child(burrow)

	conduit = ConduitGauntlet.new()
	conduit.player = self
	conduit.tuning = tuning
	add_child(conduit)


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
	grapple.update_target(has_gadget(Gadgets.GRAPPLE) and not burrow.is_active())
	_handle_melee(delta)
	conduit.update(delta)
	_move(delta)
	_handle_fire()
	_update_facing(delta)
	camera_rig.vertical_sharpness_override = tuning.grapple_camera_vertical_sharpness if grapple.is_active() else 0.0
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
	_grapple_settle = maxf(0.0, _grapple_settle - delta)
	if _sneak_spent:
		_sneak_left = 0.0
		_sneak_spent = false
	_sneak_left = maxf(0.0, _sneak_left - delta)
	_conceal_left = maxf(0.0, _conceal_left - delta)
	_flash = maxf(0.0, _flash - delta * 6.0)
	hurt_box.invulnerable = is_invulnerable()
	if input.jump_pressed:
		_jump_buffer = tuning.jump_buffer_time
	if not input.jump_held:
		_glide_needs_press = false


# --- Movement -----------------------------------------------------------------

func _move(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		_coyote = tuning.coyote_time
		_air_jumps_left = 1
		_air_dodge_used = false
		_grapple_settle = 0.0

	# Grapple-Tail: the reel owns velocity; dodge lets go (and dodges).
	var let_go := false
	if grapple.is_active():
		close_glide(true)
		if input.dodge_pressed:
			grapple.cancel()
			let_go = true
		else:
			_reel(delta)
			return

	# The left stick drives the weapon wheel while it is open, so stand still.
	var wish := Vector3.ZERO if wheel_open else camera_relative(input.move)

	# Burrow Claws: underground the claws own movement; jump / dodge pop out or tunnel.
	if burrow.is_active():
		_move_burrowed(delta, wish)
		return

	# Melee can be interrupted by dodge (always) or jump (after the hit lands).
	if melee.is_busy() and melee.can_cancel():
		var after_hit := melee.phase != StaffMelee.Phase.SWING or melee.phase_time > tuning.melee_active_end
		if input.dodge_pressed or (_jump_buffer > 0.0 and after_hit):
			melee.cancel()

	# Grapple: dodge with a ring highlighted (airborne) grapples instead of dodging.
	if input.dodge_pressed and not let_go and not melee.is_busy() and grapple.is_ready():
		close_glide(true)
		grapple.start()
		_reel(delta)
		return

	# Dodge
	if input.dodge_pressed and not melee.is_busy() and _dodge_cooldown <= 0.0 and _dodge_time <= 0.0 and (on_floor or not _air_dodge_used):
		_dodge_dir = wish.normalized() if wish.length_squared() > 0.01 else facing_forward()
		_dodge_time = tuning.dodge_duration
		_dodge_cooldown = tuning.dodge_duration + tuning.dodge_cooldown
		_dodge_iframes = tuning.dodge_iframes
		Sfx.play(&"dodge")
		_rumble(tuning.rumble_dodge)
		if not on_floor:
			_air_dodge_used = true
			velocity.y = maxf(velocity.y, 0.0)

	# A floor dodge on (or onto) a soil patch digs in.
	if is_dodging() and on_floor and has_gadget(Gadgets.BURROW):
		var soil := SoilPatch.at(get_tree(), global_position)
		if soil != null:
			_begin_burrow(soil)
			_move_burrowed(delta, wish)
			return

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
			if _grapple_settle > 0.0:
				accel *= tuning.grapple_release_air_control
		elif wish.length_squared() > 0.0001:
			accel = tuning.ground_acceleration
		else:
			accel = tuning.ground_deceleration
		h = h.move_toward(target_h, accel * delta)
	_knockback = _knockback.move_toward(Vector3.ZERO, 30.0 * delta)
	h += _knockback

	# Jump
	# (Not while rising from a hazard launch: any jump would be slower than it.)
	if _jump_buffer > 0.0 and not melee.is_busy() and not _launched:
		if on_floor or _coyote > 0.0:
			velocity.y = tuning.jump_velocity()
			Sfx.play(&"jump")
			_jump_buffer = 0.0
			_coyote = 0.0
		elif _air_jumps_left > 0:
			velocity.y = tuning.double_jump_velocity()
			Sfx.play(&"double_jump")
			_air_jumps_left -= 1
			fox_model.play_action(&"DoubleJump")
			_jump_buffer = 0.0
			_gadget_hop = false

	_update_glide(on_floor)
	var lift := SteamVent.lift_in(get_tree(), global_position + Vector3.UP * 0.5)

	# Gravity (none during an air dodge so it reads as a dash; slams set it directly)
	if cloak.is_open():
		var v := cloak.glide_velocity(delta, wish, lift)
		h = Vector3(v.x, 0.0, v.z)
		velocity.y = v.y
	elif melee.phase == StaffMelee.Phase.SLAM_HOVER:
		velocity.y = 0.0
	elif melee.phase == StaffMelee.Phase.SLAM_FALL:
		velocity.y = -tuning.slam_fall_speed
	elif not (is_dodging() and not on_floor):
		var g := tuning.gravity
		if velocity.y < 0.0:
			g *= tuning.fall_gravity_multiplier
			_launched = false
			_gadget_hop = false
		elif not input.jump_held and not _launched and not _gadget_hop:
			g *= tuning.jump_release_gravity_multiplier
		velocity.y = maxf(velocity.y - g * delta + lift * tuning.vent_push_acceleration * delta, -tuning.max_fall_speed)

	velocity.x = h.x
	velocity.z = h.z
	move_and_slide()
	if is_on_floor() and (melee.phase == StaffMelee.Phase.SLAM_FALL or melee.phase == StaffMelee.Phase.POUNCE):
		melee.land(global_position)


## Leaf-wing Cloak: open while jump is held, falling, in the air, with the
## double jump spent (so holding jump through a grapple release, which refunds
## it, never opens it: the next press double jumps, then holding glides).
func _update_glide(on_floor: bool) -> void:
	var can := has_gadget(Gadgets.GLIDE) and not on_floor and input.jump_held and not _glide_needs_press \
			and not is_dodging() and not melee.is_busy() and not grapple.is_active() and not wheel_open
	if cloak.is_open():
		if not can:
			close_glide(is_dodging())
	elif can and velocity.y < 0.0 and _air_jumps_left <= 0:
		cloak.open()


func is_gliding() -> bool:
	return cloak.is_open()


## Fold the cloak. `forced` (dodge, grapple, hit) keeps it shut until jump is pressed again.
func close_glide(forced: bool = false) -> void:
	if forced and cloak.is_open():
		_glide_needs_press = true
	cloak.close()


## One frame on the grapple line. Buffered jumps are dropped so a press during
## the reel does not eat the release hop.
func _reel(delta: float) -> void:
	_jump_buffer = 0.0
	_knockback = Vector3.ZERO
	velocity = grapple.reel(delta)
	if grapple.just_released:
		_gadget_hop = true
		_grapple_settle = tuning.grapple_release_settle_time
		_coyote = 0.0
		_air_jumps_left = 1
	move_and_slide()


# --- Burrow -------------------------------------------------------------------

func is_burrowed() -> bool:
	return burrow.is_active()


## Unseen by enemy perception: underground, or just popped out (conceal time).
func is_hidden() -> bool:
	return burrow.is_active() or _conceal_left > 0.0


## The next staff swing hit is a sneak attack (window after popping out).
func is_sneak_ready() -> bool:
	return _sneak_left > 0.0


func _begin_burrow(soil: SoilPatch) -> void:
	_dodge_time = 0.0
	_dodge_iframes = 0.0
	_jump_buffer = 0.0
	_knockback = Vector3.ZERO
	_sneak_left = 0.0
	_conceal_left = 0.0
	_burrow_hop = false
	_melee_after_hop = false
	close_glide()
	melee.cancel()
	# No bumping into enemies down there (they walk over the mound).
	collision_layer = 0
	collision_mask = Layers.WORLD
	burrow.start(soil)


## One frame underground. Jump pops out; dodge tunnels to a linked patch (or
## pops out of a standalone one). No firing, staff or grapple down here.
func _move_burrowed(delta: float, wish: Vector3) -> void:
	_jump_buffer = 0.0
	_knockback = Vector3.ZERO
	burrow.tick(delta)
	if burrow.is_under():
		if input.jump_pressed or (input.dodge_pressed and not burrow.start_tunnel()):
			_end_burrow(true)
			move_and_slide()
			return
	if burrow.phase == BurrowClaws.Phase.TUNNEL:
		velocity = Vector3.ZERO
		global_position = burrow.tunnel_position()
		return
	var h := burrow.move_velocity(delta, wish)
	velocity.x = h.x
	velocity.z = h.z
	velocity.y = maxf(velocity.y - tuning.gravity * delta, -tuning.max_fall_speed)
	move_and_slide()
	burrow.confine()


## Leave the ground. `hop` = the pop-out (sneak window, conceal, small hop);
## false drops out quietly (death, respawn, launch).
func _end_burrow(hop: bool) -> void:
	if not burrow.is_active():
		return
	collision_layer = Layers.PLAYER
	collision_mask = Layers.WORLD | Layers.ENEMY
	if not hop:
		burrow.cancel()
		return
	burrow.surface()
	velocity.y = tuning.burrow_pop_velocity()
	_gadget_hop = true
	_coyote = 0.0
	_air_jumps_left = 1
	_sneak_left = tuning.burrow_sneak_window
	_conceal_left = tuning.burrow_surface_conceal_time
	_burrow_hop = true
	_melee_after_hop = input.melee_pressed  # staff pressed with the pop: swing on landing


## Death / respawn: out of the ground, no sneak window.
func _reset_burrow() -> void:
	_end_burrow(false)
	_burrow_hop = false
	_melee_after_hop = false
	_sneak_left = 0.0
	_conceal_left = 0.0


## A staff hit landing ends the pop-out concealment (the victim, now aware,
## must not lose track of the fox at once).
func _on_staff_hit(_hb: HurtBox, _info: DamageInfo) -> void:
	_conceal_left = 0.0


## Staff swing damage_modifier: inside the sneak window an unaware enemy takes
## burrow_sneak_multiplier (shown as a critical). Any enemy hit spends the window.
func _sneak_modifier(hb: HurtBox, info: DamageInfo) -> void:
	if _sneak_left <= 0.0:
		return
	var e := Enemy.from_hurt_box(hb)
	if e == null or e.health.is_dead:
		return
	_sneak_spent = true
	if not e.aware:
		info.amount *= tuning.burrow_sneak_multiplier
		info.is_critical = true
		sneak_attacked.emit(e)


# --- Melee --------------------------------------------------------------------

func _handle_melee(delta: float) -> void:
	var pressed := input.melee_pressed
	if _burrow_hop:
		if is_on_floor():
			_burrow_hop = false
			pressed = pressed or _melee_after_hop
			_melee_after_hop = false
		elif pressed:
			_melee_after_hop = true
			pressed = false
	if pressed and not is_dodging() and not wheel_open and not grapple.is_active() and not burrow.is_active():
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
	# No enemy: a charged gauntlet turns to a dead conduit terminal instead.
	if best == null and conduit.is_charged() and has_gadget(Gadgets.CONDUIT):
		for n: Node3D in AimAssist.nodes_in_group(get_tree(), ConduitTerminal.GROUP):
			var term := n as ConduitTerminal
			var to := n.global_position - global_position
			to.y = 0.0
			var dist := to.length()
			if term.is_powered or dist < 0.01 or dist > best_dist:
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


## Top speed for a wish direction: full run, strafe (tuning multipliers) or scoped.
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
	return input.strafe_held and not is_dead and not cloak.is_open()


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
	elif grapple.is_active():
		var to_ring := grapple.ring_direction()
		if to_ring != Vector3.ZERO:
			target_yaw = yaw_of(to_ring)
	elif cloak.is_open() and _fire_facing <= 0.0:
		target_yaw = yaw_of(cloak.heading)
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
	return _dodge_iframes > 0.0 or _hurt_iframes > 0.0 or burrow.is_active()


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
	var firing := input.fire_held and not is_dodging() and not melee.is_busy() and not wheel_open \
			and not grapple.is_active() and not burrow.is_active()
	if firing:
		_fire_facing = tuning.fire_facing_time
		_conceal_left = 0.0  # shooting gives the fox away
	if input.fire_held and not firing:
		w.cancel_charge()
	w.trigger(firing, current_aim())


## Hold the wheel button: time slows, the left stick (or WASD/mouse) highlights a
## slot, releasing equips it. Movement, camera, firing
## and melee are paused while it is open.
func _update_wheel() -> void:
	if input.wheel_held and not wheel_open and not weapons.is_empty():
		wheel_open = true
		wheel_highlight = current_weapon_index
		wheel_page = page_of(current_weapon_index)
		_wheel_cursor = Vector2.ZERO
		GameFeel.set_slowmo(WHEEL_SLOWMO, tuning.wheel_time_scale)
		Sfx.play(&"wheel_open")
		_wheel_heard = wheel_highlight
		wheel_toggled.emit(true)
	elif not input.wheel_held and wheel_open:
		close_wheel(true)
	if not wheel_open:
		return
	# LB/RB flip pages while open (and must not also cycle weapons).
	if input.weapon_next or input.weapon_prev:
		var pages := wheel_page_count()
		wheel_page = (wheel_page + (1 if input.weapon_next else pages - 1)) % pages
		wheel_highlight = mini(wheel_page * WHEEL_PAGE_SIZE + (wheel_highlight % WHEEL_PAGE_SIZE), weapons.size() - 1)
		input.weapon_next = false
		input.weapon_prev = false
	var slots := wheel_page_slots(wheel_page)
	_wheel_cursor = (_wheel_cursor + input.mouse_look).limit_length(tuning.wheel_mouse_threshold * 3.0)
	if input.move.length() >= tuning.wheel_stick_threshold:
		wheel_highlight = wheel_page * WHEEL_PAGE_SIZE + WeaponWheel.index_for_direction(input.move, slots)
	elif _wheel_cursor.length() >= tuning.wheel_mouse_threshold:
		wheel_highlight = wheel_page * WHEEL_PAGE_SIZE + WeaponWheel.index_for_direction(_wheel_cursor, slots)
	if wheel_highlight != _wheel_heard:
		_wheel_heard = wheel_highlight
		Sfx.play(&"wheel_select")


func wheel_page_count() -> int:
	return maxi(1, ceili(float(weapons.size()) / WHEEL_PAGE_SIZE))


func wheel_page_slots(page: int) -> int:
	return clampi(weapons.size() - page * WHEEL_PAGE_SIZE, 0, WHEEL_PAGE_SIZE)


func page_of(index: int) -> int:
	return floori(float(index) / WHEEL_PAGE_SIZE)


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
	# Number keys pick from the wheel page last viewed.
	var slot := wheel_page * WHEEL_PAGE_SIZE + input.weapon_slot
	if input.weapon_slot >= 0 and slot < weapons.size():
		_select_weapon(slot)
	elif input.weapon_next:
		_select_weapon((current_weapon_index + 1) % weapons.size())
	elif input.weapon_prev:
		_select_weapon((current_weapon_index - 1 + weapons.size()) % weapons.size())


func select_weapon(index: int) -> void:
	_select_weapon(index)


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


## Sounds and rumble for events the components report.
func _connect_feedback() -> void:
	melee.swung.connect(func(_index: int) -> void: Sfx.play(&"swing"))
	melee.slammed.connect(func(at: Vector3) -> void: Sfx.play(&"impact_heavy", at))
	fox_model.landed.connect(func(air_time: float) -> void:
		var k := clampf(air_time / tuning.land_rumble_full_air_time, 0.0, 1.0)
		Sfx.play(&"land", null, linear_to_db(0.4 + 0.6 * k))
		GameFeel.rumble(tuning.rumble_land.x * k, tuning.rumble_land.y * k, tuning.rumble_land.z))
	grapple.started.connect(func(_ring: GrappleRing) -> void:
		Sfx.play(&"grapple")
		_rumble(tuning.rumble_grapple))
	cloak.opened.connect(func() -> void: Sfx.play(&"glide"))
	var dig := func(_a: Variant = null, _b: Variant = null) -> void:
		Sfx.play(&"dig")
		_rumble(tuning.rumble_burrow)
	burrow.dived.connect(dig)
	burrow.tunnelled.connect(dig)
	burrow.surfaced.connect(dig)
	gadgets.unlocked_gadget.connect(func(_id: StringName) -> void: Sfx.play(&"level_up"))
	conduit.absorbed.connect(func(_source: Node3D) -> void: Sfx.play(&"conduit_charge"))
	conduit.discharged.connect(func(_chain: Array[Enemy]) -> void: Sfx.play(&"shot_zap", null, 4.0))


func _rumble(r: Vector3) -> void:
	GameFeel.rumble(r.x, r.y, r.z)


func _on_weapon_leveled(level: int, w: Weapon) -> void:
	GameFeel.impact(global_position + Vector3.UP, w.data.color, 3.0, 0.4)
	Sfx.play(&"level_up")
	GameFeel.hit_stop(tuning.level_up_slowmo_time, tuning.level_up_slowmo_scale)
	_rumble(tuning.rumble_level_up)
	weapon_leveled.emit(w, level)


# --- Damage -------------------------------------------------------------------

## Hazard bounce (lava): straight up at `speed`, even during i-frames, so the
## fox can never stand in it. Ends a dodge, restores the double jump so the
## player can steer out, and the full arc plays whether or not jump is held.
func launch_up(speed: float) -> void:
	if is_dead:
		return
	velocity.y = maxf(velocity.y, speed)
	_launched = true
	grapple.cancel()
	_end_burrow(false)
	_burrow_hop = false
	close_glide(true)
	_dodge_time = 0.0
	_coyote = 0.0
	_air_jumps_left = 1


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP * HEIGHT * 0.55


func _on_hurt(info: DamageInfo) -> void:
	if info.is_dot:
		return
	_hurt_iframes = tuning.hurt_iframes
	hurt_box.invulnerable = true
	_flash = 1.0
	fox_model.play_action(&"Hurt")
	Sfx.play(&"player_hurt")
	GameFeel.shake(0.5)
	GameFeel.hit_stop(0.05)
	# On the grapple line small hits are shrugged off; big ones knock you off it.
	if grapple.is_active():
		if info.knockback < tuning.grapple_cancel_knockback:
			return
		grapple.cancel()
	if info.knockback >= tuning.glide_cancel_knockback or info.knockback_up > 0.0:
		close_glide(true)
	var away := global_position - info.source_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = -facing_forward()
	_knockback = away.normalized() * info.knockback * tuning.hurt_knockback_scale
	velocity.y = maxf(velocity.y, info.knockback_up)


func _on_died(_info: DamageInfo) -> void:
	is_dead = true
	_respawn_timer = RESPAWN_DELAY
	velocity = Vector3.ZERO
	current_weapon().on_unequipped()
	melee.cancel()
	grapple.cancel()
	close_glide()
	_reset_burrow()
	conduit.clear()  # a stored charge is lost on death (not on a fall)
	close_wheel(false)
	visual.visible = false
	GameFeel.impact(global_position + Vector3.UP, BODY_COLOR, 3.0, 0.5)
	died.emit()


func respawn() -> void:
	is_dead = false
	global_position = spawn_point
	facing_yaw = spawn_yaw
	camera_rig.yaw = spawn_yaw
	visual.rotation.y = spawn_yaw
	velocity = Vector3.ZERO
	_knockback = Vector3.ZERO
	_launched = false
	_gadget_hop = false
	grapple.cancel()
	close_glide()
	_reset_burrow()
	health.reset()
	_hurt_iframes = tuning.hurt_iframes
	visual.visible = true
	camera_rig.snap_to_target()
	respawned.emit()


func has_gadget(id: StringName) -> bool:
	return gadgets.has(id)


func unlock_gadget(id: StringName) -> bool:
	return gadgets.unlock(id)


func _update_visuals(_delta: float) -> void:
	fox_model.flash(_flash)
	_gun.visible = not melee.is_drawn()
	fox_model.aim((_fire_facing > 0.0 or is_strafing()) and not melee.is_busy() and not grapple.is_active()
			and not burrow.is_active(), rad_to_deg(asin(clampf(aim_direction.y, -1.0, 1.0))))
	fox_model.set_travel(Vector3(velocity.x, 0.0, velocity.z))
	fox_model.update(Vector2(velocity.x, velocity.z).length(), is_on_floor(), velocity.y, _anim_hold())
	grapple.update_rope()
	cloak.update_visual(_delta)
	burrow.update_visual(_delta)
	conduit.update_visual(_delta)
	# Blink during hurt i-frames (not dodge i-frames: dodging should look clean).
	visual.visible = _hurt_iframes <= 0.0 or fmod(_hurt_iframes, 0.12) > 0.05
	# Hide the fox once the scope is mostly zoomed in; at that FOV it fills the frame.
	if is_zoomed() and camera_rig.camera.fov < tuning.camera_fov * 0.6:
		visual.visible = false
	# Burrowed: the fox sinks into the soil, then only the dirt mound shows.
	var sink := burrow.sink()
	visual.position.y = -HEIGHT * sink
	if sink >= 1.0:
		visual.visible = false


## The clip the fox's current state pins (FoxModel `hold`), or none.
func _anim_hold() -> StringName:
	if is_dodging():
		return &"Dodge"
	match melee.phase:
		StaffMelee.Phase.SLAM_HOVER, StaffMelee.Phase.POUNCE:
			return &"SlamRise"
		StaffMelee.Phase.SLAM_FALL:
			return &"SlamFall"
		StaffMelee.Phase.SLAM_RECOVER:
			return &"SlamLand"
	if grapple.is_active():
		return &"Reel"
	if cloak.is_open():
		return &"Glide"
	return &""
