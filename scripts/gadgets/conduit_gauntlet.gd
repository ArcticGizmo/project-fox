class_name ConduitGauntlet
extends Node3D
## Copper Conduit Gauntlet (gadget &"conduit"). A component on the player, like
## BurrowClaws. No new buttons: the staff does it. Every live staff swing is
## checked for ConduitSockets (Layers.CONDUCTOR, which only the swing HitBox
## masks); each socket hears about a swing once via `conduit_struck`:
##   LightningBarrier, live (on, or charging past its absorb_min_charge):
##     with the gadget it is drained (goes off) and the gauntlet gains a charge.
##   ConduitTerminal, dead: with a charge it spends it and powers up; otherwise
##     a dull clank.
## While charged the copper cuff and staff glow arc-blue and crackle. The charge
## lasts until spent (or the fox dies). A charged swing that hits an enemy
## spends it instead as chain lightning that staggers (discharge()).
##
## Feel numbers: the "Conduit" group of PlayerTuning.

signal absorbed(source: Node3D)
signal spent(into: Node3D)
signal discharged(chain: Array[Enemy])

const CHARGE_COLOR := Color(0.55, 0.85, 1.0)
const COPPER := Color(0.78, 0.42, 0.24)
const CRACKLE_BOLTS := 2
const CRACKLE_SEGMENTS := 6
const CRACKLE_INTERVAL := 0.05

var player: Player
var tuning: PlayerTuning
var charges: int = 0
## Enemies hit by the last discharge, in chain order (tests, debugging).
var last_chain: Array[Enemy] = []

var _struck: Dictionary = {}
var _age: float = 0.0
var _pulse: float = 0.0
var _crackle_timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _rig: Node3D
var _cuff_material: StandardMaterial3D
var _orb: MeshInstance3D
var _orb_material: StandardMaterial3D
var _light: OmniLight3D
var _bolt_material: StandardMaterial3D
var _bolts: Array[Array] = []


func _ready() -> void:
	name = "ConduitGauntlet"
	_build_visual()


func is_charged() -> bool:
	return charges > 0


func is_full() -> bool:
	return charges >= tuning.conduit_max_charges


## Store a charge taken from `source` (a barrier). False when already full.
func add_charge(source: Node3D, contact: Vector3) -> bool:
	if is_full():
		return false
	charges += 1
	_pulse = 1.0
	_bolt_to_tip(contact)
	GameFeel.impact(tip_position(), Color(CHARGE_COLOR, 0.8), 1.4, 0.2)
	GameFeel.shake(0.25)
	GameFeel.hit_stop(0.05)
	absorbed.emit(source)
	return true


## Spend a charge into `into` (a terminal). False when empty.
func spend(into: Node3D, contact: Vector3) -> bool:
	if charges <= 0:
		return false
	charges -= 1
	_pulse = 1.0
	_bolt_to_tip(contact)
	GameFeel.impact(contact, Color(CHARGE_COLOR, 0.8), 1.2, 0.2)
	GameFeel.shake(0.2)
	GameFeel.hit_stop(0.04)
	spent.emit(into)
	return true


func clear() -> void:
	charges = 0
	_struck.clear()


func tip_position() -> Vector3:
	var pivot := player.melee.staff_pivot()
	return pivot.to_global(Vector3(0, 0, StaffMelee.STAFF_TIP_Z))


## Called every physics frame after the staff updates: hand each socket inside a
## live swing to its receiver, once per swing.
func update(_delta: float) -> void:
	var hb := player.melee.hit_box
	if not hb.active or player.melee.phase != StaffMelee.Phase.SWING:
		_struck.clear()
		return
	var unlocked := player.has_gadget(Gadgets.CONDUIT)
	for area: Area3D in hb.get_overlapping_areas():
		var socket := area as ConduitSocket
		if socket == null or _struck.has(socket.get_instance_id()):
			continue
		_struck[socket.get_instance_id()] = true
		socket.strike(self, unlocked)


## Staff swing hit on a hurtbox: a charged gauntlet discharges into an enemy.
func on_staff_hit(hb: HurtBox, _info: DamageInfo) -> void:
	if charges <= 0 or not player.has_gadget(Gadgets.CONDUIT):
		return
	var first := Enemy.from_hurt_box(hb)
	if first == null:
		return
	charges -= 1
	_pulse = 1.0
	discharge(first)


## Chain lightning: the enemy hit, then up to conduit_chain_jumps more (nearest
## un-hit within conduit_chain_radius with a clear line). Each takes
## conduit_chain_damage and is staggered. No weapon is credited.
func discharge(first: Enemy) -> void:
	last_chain.clear()
	var from := tip_position()
	var current := first
	var space := get_world_3d().direct_space_state
	for _i: int in tuning.conduit_chain_jumps + 1:
		var point := current.get_aim_point()
		_jagged(from, point)
		last_chain.append(current)
		if not current.health.is_dead:
			current.hurt_box.receive(DamageInfo.create(tuning.conduit_chain_damage, from, 0.0))
			current.stagger(tuning.conduit_chain_stagger)
		GameFeel.impact(point, Color(CHARGE_COLOR, 0.8), 1.0, 0.15)
		from = point
		current = _nearest_unhit(point, space)
		if current == null:
			break
	GameFeel.shake(0.3)
	discharged.emit(last_chain)


func _nearest_unhit(from: Vector3, space: PhysicsDirectSpaceState3D) -> Enemy:
	var best: Enemy = null
	var best_dist := tuning.conduit_chain_radius
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e := n as Enemy
		if e == null or e in last_chain or e.health.is_dead:
			continue
		var p := e.get_aim_point()
		var d := from.distance_to(p)
		if d < best_dist and AimAssist.has_line_of_sight(space, from, p):
			best = e
			best_dist = d
	return best


# --- Visuals --------------------------------------------------------------------

func _build_visual() -> void:
	_rig = Node3D.new()
	_rig.name = "GauntletRig"
	player.melee.staff_pivot().add_child(_rig)
	_cuff_material = StandardMaterial3D.new()
	_cuff_material.albedo_color = COPPER
	_cuff_material.metallic = 0.6
	_cuff_material.roughness = 0.35
	_cuff_material.emission_enabled = true
	_cuff_material.emission = Color.BLACK
	# Cuff at the grip plus two copper coil bands up the staff.
	for band: Vector2 in [Vector2(-0.05, 0.12), Vector2(-0.75, 0.075), Vector2(-1.3, 0.075)]:
		var cyl := CylinderMesh.new()
		cyl.top_radius = band.y
		cyl.bottom_radius = band.y
		cyl.height = 0.28 if band.x > -0.1 else 0.1
		var mi := MeshInstance3D.new()
		mi.mesh = cyl
		mi.material_override = _cuff_material
		mi.rotation.x = PI * 0.5
		mi.position.z = band.x
		_rig.add_child(mi)

	_orb_material = StandardMaterial3D.new()
	_orb_material.albedo_color = Color(CHARGE_COLOR, 0.85)
	_orb_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_orb_material.emission_enabled = true
	_orb_material.emission = CHARGE_COLOR * 3.0
	var sphere := SphereMesh.new()
	sphere.radius = 0.14
	sphere.height = 0.28
	_orb = MeshInstance3D.new()
	_orb.mesh = sphere
	_orb.material_override = _orb_material
	_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_orb.position.z = StaffMelee.STAFF_TIP_Z
	_rig.add_child(_orb)

	_light = OmniLight3D.new()
	_light.light_color = CHARGE_COLOR
	_light.light_energy = 1.5
	_light.omni_range = 3.5
	_light.position.z = StaffMelee.STAFF_TIP_Z * 0.6
	_rig.add_child(_light)

	_bolt_material = StandardMaterial3D.new()
	_bolt_material.albedo_color = Color(CHARGE_COLOR, 0.9)
	_bolt_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bolt_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var seg := BoxMesh.new()
	seg.size = Vector3(0.035, 0.035, 1.0)
	for _b: int in CRACKLE_BOLTS:
		var bolt: Array[MeshInstance3D] = []
		for _s: int in CRACKLE_SEGMENTS:
			var mi := MeshInstance3D.new()
			mi.mesh = seg
			mi.material_override = _bolt_material
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_rig.add_child(mi)
			bolt.append(mi)
		_bolts.append(bolt)
	update_visual(0.0)


func cuff_visible() -> bool:
	return _rig.visible


func crackle_visible() -> bool:
	return _orb.visible


func update_visual(delta: float) -> void:
	_age += delta
	_pulse = maxf(0.0, _pulse - delta * 3.0)
	_rig.visible = player.has_gadget(Gadgets.CONDUIT)
	var charged := is_charged()
	_orb.visible = charged
	_light.visible = charged and _rig.visible
	var flicker := 0.8 + 0.4 * absf(sin(_age * 31.0))
	_cuff_material.emission = CHARGE_COLOR * ((1.2 * flicker if charged else 0.0) + 2.0 * _pulse)
	player.melee.staff_material.emission = CHARGE_COLOR * ((0.35 * flicker if charged else 0.0) + 0.8 * _pulse)
	_orb.scale = Vector3.ONE * (1.0 + 0.6 * _pulse + 0.12 * sin(_age * 23.0))
	_light.light_energy = 1.2 * flicker + 2.0 * _pulse
	_crackle_timer -= delta
	if not charged:
		for bolt: Array in _bolts:
			for mi: MeshInstance3D in bolt:
				mi.visible = false
		return
	if _crackle_timer > 0.0:
		return
	_crackle_timer = CRACKLE_INTERVAL
	# Jagged arcs from the cuff to the tip, re-rolled every few frames.
	for bolt: Array in _bolts:
		var prev := Vector3(0, 0, -0.1)
		for s: int in CRACKLE_SEGMENTS:
			var mi := bolt[s] as MeshInstance3D
			var t := float(s + 1) / CRACKLE_SEGMENTS
			var j := 0.0 if s == CRACKLE_SEGMENTS - 1 else 0.13
			var next := Vector3(_rng.randf_range(-j, j), _rng.randf_range(-j, j), lerpf(-0.1, StaffMelee.STAFF_TIP_Z, t))
			var d := next - prev
			mi.visible = _rng.randf() < 0.85
			mi.transform = Transform3D(Basis.looking_at(d.normalized(), Vector3.UP) * Basis.from_scale(Vector3(1, 1, d.length())), (prev + next) * 0.5)
			prev = next


func _bolt_to_tip(contact: Vector3) -> void:
	_jagged(contact, tip_position())


func _jagged(a: Vector3, b: Vector3) -> void:
	var points: Array[Vector3] = [a]
	var dir := b - a
	if dir.length_squared() < 0.0001:
		return
	var perp := dir.cross(Vector3.UP)
	perp = perp.normalized() if perp.length_squared() > 0.0001 else Vector3.RIGHT
	for i: int in range(1, 4):
		var offset := perp.rotated(dir.normalized(), _rng.randf() * TAU) * _rng.randf_range(-0.3, 0.3)
		points.append(a + dir * (float(i) / 4.0) + offset)
	points.append(b)
	var parent := player.get_parent()
	for i: int in points.size() - 1:
		Tracer.spawn(parent, points[i], points[i + 1], CHARGE_COLOR, 0.06, 0.15)
