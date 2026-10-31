class_name Enemy
extends CharacterBody3D
## Base enemy: a coloured primitive body, a hurtbox, health and a small state
## machine. Subclasses implement attack patterns in _tick_state().
##
## Sizing (metres, origin at the feet). For scale, the fox is 0.9 wide, 1.8 tall.
##   BOX      body_size = width, height, length
##   SPHERE   body_size.x = diameter (y, z ignored)
##   CAPSULE  body_size.x = diameter, body_size.y = height
##   CYLINDER body_size.x = diameter, body_size.y = height
##
## Telegraphs: set `telegraph` (0..1) to glow yellow and `visual_scale` to
## squash/stretch the body during wind-ups. Both reset on every state change.

signal died(enemy: Enemy)

enum BodyShape { BOX, SPHERE, CAPSULE, CYLINDER }

const TELEGRAPH_COLOR := Color(1.0, 0.85, 0.15)
const BURN_COLOR := Color(1.0, 0.35, 0.0)
const FLINCH := &"flinch"
const BURN_TICK := 0.25
const CHILL_DECAY_PER_SEC := 0.25
## Chill only starts to decay this long after the last chilling hit.
const CHILL_DECAY_DELAY := 1.0
## Full chill slows movement and the AI clock by this fraction.
const CHILL_MAX_SLOW := 0.6
const FROZEN_DAMAGE_MULTIPLIER := 1.5
const EXPOSED_DAMAGE_MULTIPLIER := 1.3
const POISON_DPS_PER_STACK := 3.0
const POISON_MAX_STACKS := 8
const POISON_DURATION := 5.0
const POISON_TICK := 0.5
const CONTAGION_RADIUS := 4.5
const FREEZE_COLOR := Color(0.6, 0.88, 1.0)
## Blue glow at full chill, so the build-up towards a freeze reads clearly.
const CHILL_GLOW := Color(0.15, 0.45, 1.0)
const POISON_COLOR := Color(0.4, 1.0, 0.2)
const EXPOSED_COLOR := Color(0.75, 0.3, 1.0)

# Awareness states (aware == false). Noticing ends in `alert`, then `idle`.
const REST := &"rest"
const WANDER := &"wander"
const PATROL := &"patrol"
const SUSPICIOUS := &"suspicious"
const INVESTIGATE := &"investigate"
const ALERT := &"alert"
const RETURN_HOME := &"return_home"
const NEAR_NOTICE_BOOST := 1.5
const FAR_NOTICE_FACTOR := 0.5
## Aware enemies keep sight of their target out to sight_range * this, any direction.
const AWARE_SIGHT_FACTOR := 1.5
const GROUP_ALERT_DELAY_MIN := 0.15
const GROUP_ALERT_DELAY_MAX := 0.4
const ARRIVE_DISTANCE := 0.7
## Leashed enemies walk home at this fraction of move_speed.
const RETURN_SPEED_FACTOR := 0.75
## Upward stretch of the alert pop (wind-ups squash, so this reads differently).
const ALERT_POP_SCALE := Vector3(0.8, 1.4, 0.8)
## Enemies that fall below this (off a ledge into a pit) die.
const KILL_PLANE_Y := -20.0

@export_group("Body")
@export var display_name: String = "Enemy"
@export var body_shape: BodyShape = BodyShape.BOX
@export var body_size: Vector3 = Vector3.ONE
@export var color: Color = Color.WHITE
## Hurtbox size relative to the body. Above 1 makes the enemy easier to hit.
@export var hurtbox_scale: float = 1.0

@export_group("Stats")
@export var max_health: float = 50.0
@export var move_speed: float = 4.0
@export var acceleration: float = 30.0
@export var turn_speed_deg: float = 360.0
@export var xp_value: int = 10
## 0 = full knockback, 1 = immovable.
@export_range(0.0, 1.0) var knockback_resistance: float = 0.0
## Interrupt the current (interruptible) state when damaged.
@export var flinch_on_hit: bool = false
@export var flinch_time: float = 0.25
@export var gravity: float = 30.0
## Fixed RNG seed for deterministic tests; -1 = random.
@export var random_seed: int = -1

@export_group("Flight")
## Flyers ignore gravity and steer vertically with desired_velocity.y (see
## hover_velocity()). Frozen flyers drop like a stone until they thaw.
@export var flying: bool = false
## Cruising height above the ground for hover_velocity().
@export var hover_height: float = 5.0
@export var climb_speed: float = 4.0

@export_group("Status effects")
## Scales chill, freeze, root and stagger strength/duration. 0 = immune.
@export_range(0.0, 2.0) var status_resistance: float = 1.0

@export_group("Awareness")
## False = starts unaware at its home (placed enemies). WaveManager and
## TestCase.spawn_enemy use make_always_aware() instead.
@export var starts_aware: bool = false
@export var sight_range: float = 18.0
## Full width of the sight cone. Point-blank range ignores the cone.
@export var sight_fov_deg: float = 110.0
## Hears a NoiseEvent when distance <= noise radius + hearing_range.
@export var hearing_range: float = 6.0
## Seconds of continuous sight to fill suspicion at half sight_range. Up close
## it fills NEAR_NOTICE_BOOST times faster, at the edge FAR_NOTICE_FACTOR times.
@export var notice_time: float = 1.2
## Suspicion lost per second while nothing is seen.
@export var suspicion_decay: float = 0.35
## Length of the "noticed you" pop before combat starts.
@export var alert_time: float = 0.5
## Entering alert wakes unaware enemies this close with line of sight to it.
@export var alert_radius: float = 10.0
## Aware enemies further than this from home walk back. 0 = never.
@export var leash_radius: float = 25.0
## Aware enemies that have not seen their target for this long walk home. 0 = never.
@export var forget_time: float = 6.0
## Anyone this close with line of sight is noticed at once (no cone, no alert pop).
@export var point_blank_range: float = 3.0
## Random wander points this far from home between rests. 0 = rest in place.
## Marker3D children override this with a patrol route (visited in order).
@export var wander_radius: float = 0.0
@export var rest_time_min: float = 2.0
@export var rest_time_max: float = 4.0
## Walking speed while unaware (wander, patrol, investigate, return home).
@export var unaware_speed_factor: float = 0.45
## Seconds spent looking around at an investigated point before heading home.
@export var investigate_time: float = 2.5

var health: Health
var hurt_box: HurtBox
var visual: Node3D
var target: Node3D
var state: StringName = &""
var state_time: float = 0.0
## "state@seconds" for every transition. Tests use this to verify attack timings.
var state_log: PackedStringArray = PackedStringArray()
var desired_velocity: Vector3 = Vector3.ZERO
var telegraph: float = 0.0
var visual_scale: Vector3 = Vector3.ONE
## Nose-down tilt of the body in radians (dives). Resets on every state change.
var visual_pitch: float = 0.0
## Idle-flavour offsets on the Visual node (reset on every state change).
var visual_yaw: float = 0.0
var visual_offset: Vector3 = Vector3.ZERO
var marker: AwarenessMarker
var ai_view: AiDebugView
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _age: float = 0.0
var _move_velocity: Vector3 = Vector3.ZERO
var _knockback: Vector3 = Vector3.ZERO
var _flash: float = 0.0
var _material: StandardMaterial3D
var _label: Label3D
var _burn_dps: float = 0.0
var _burn_left: float = 0.0
var _burn_tick: float = 0.0
var _burn_source: Weapon = null

## 0..1. Slows the enemy; reaching 1 freezes it.
var chill: float = 0.0
var _chill_hold: float = 0.0
var frozen_left: float = 0.0
var rooted_left: float = 0.0
var staggered_left: float = 0.0
var exposed_left: float = 0.0
var poison_stacks: int = 0
var _poison_left: float = 0.0
var _poison_tick: float = 0.0
var _poison_source: Weapon = null
var _poison_contagious: bool = false
var _was_disabled: bool = false
var _web: Node3D
## Transparent ice block shown around the body while frozen.
var ice_block: MeshInstance3D

## True once the enemy has noticed someone; combat states (_tick_state) only
## run while aware. Unaware enemies run the AWARENESS_STATES below.
var aware: bool = false
## 0..1 while unaware; 1 means noticed.
var suspicion: float = 0.0
var home_position: Vector3 = Vector3.ZERO
var home_yaw: float = 0.0
## Global positions of the Marker3D children at _ready (patrol route).
var patrol_points: Array[Vector3] = []
## Perception results from the last check (read by the AI debug view).
var sees_target: bool = false
## True when the last line-of-sight ray to the target hit WORLD geometry.
var los_blocked: bool = false
## Whether a line-of-sight ray was cast on the last check (in range).
var los_checked: bool = false
var last_seen_position: Vector3 = Vector3.ZERO
var investigate_point: Vector3 = Vector3.ZERO
## Seconds since an aware enemy last saw its target (forget_time).
var unseen_time: float = 0.0
## The enemy whose alert woke this one (debug view link), or null.
var alerted_by: Enemy = null
## Age (seconds) when alerted_by reached this enemy.
var alerted_at: float = -1.0
var _alert_spreads: bool = true
var _alert_delay: float = -1.0
var _rest_duration: float = 0.0
var _walk_goal: Vector3 = Vector3.ZERO
var _walk_limit: float = 0.0
var _look_left: float = -1.0
var _patrol_index: int = 0
## Distance from the eye to the target on the last perception check.
var perceived_distance: float = INF


func _ready() -> void:
	add_to_group(&"enemies")
	add_to_group(&"aim_targets")
	collision_layer = Layers.ENEMY
	collision_mask = Layers.WORLD | Layers.ENEMY | Layers.PLAYER
	if random_seed >= 0:
		rng.seed = random_seed
	else:
		rng.randomize()
	_build_body()

	health = Health.new()
	health.name = "Health"
	health.max_health = max_health
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)

	hurt_box = HurtBox.new()
	hurt_box.name = "HurtBox"
	hurt_box.collision_layer = Layers.ENEMY_HURTBOX
	hurt_box.health = health
	hurt_box.incoming_modifier = _modify_incoming
	var hcs := CollisionShape3D.new()
	hcs.shape = make_shape(body_shape, body_size * hurtbox_scale)
	hcs.position.y = extents().y * 0.5
	hurt_box.add_child(hcs)
	add_child(hurt_box)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 22
	_label.outline_size = 6
	_label.pixel_size = 0.005
	_label.position.y = extents().y + 0.6
	_label.visible = DebugSettings.show_boxes
	add_child(_label)
	DebugSettings.show_boxes_changed.connect(_on_show_boxes_changed)
	marker = AwarenessMarker.attach(self)
	DebugSettings.show_ai_changed.connect(_on_show_ai_changed)
	_on_show_ai_changed(DebugSettings.show_ai)

	home_position = global_position
	home_yaw = rotation.y
	for c: Node in get_children():
		if c is Marker3D:
			patrol_points.append((c as Marker3D).global_position)

	_setup()
	if starts_aware:
		aware = true
		suspicion = 1.0
		enter_state(&"idle")
	else:
		enter_state(REST)


## Actual extents of the body after shape rules (see class docs).
func extents() -> Vector3:
	match body_shape:
		BodyShape.SPHERE:
			return Vector3.ONE * body_size.x
		BodyShape.CAPSULE, BodyShape.CYLINDER:
			return Vector3(body_size.x, body_size.y, body_size.x)
	return body_size


static func make_shape(shape_kind: BodyShape, size: Vector3) -> Shape3D:
	match shape_kind:
		BodyShape.SPHERE:
			var s := SphereShape3D.new()
			s.radius = size.x * 0.5
			return s
		BodyShape.CAPSULE:
			var c := CapsuleShape3D.new()
			c.radius = size.x * 0.5
			c.height = maxf(size.y, size.x)
			return c
		BodyShape.CYLINDER:
			var cy := CylinderShape3D.new()
			cy.radius = size.x * 0.5
			cy.height = size.y
			return cy
	var b := BoxShape3D.new()
	b.size = size
	return b


static func make_mesh(shape_kind: BodyShape, size: Vector3) -> Mesh:
	match shape_kind:
		BodyShape.SPHERE:
			var s := SphereMesh.new()
			s.radius = size.x * 0.5
			s.height = size.x
			return s
		BodyShape.CAPSULE:
			var c := CapsuleMesh.new()
			c.radius = size.x * 0.5
			c.height = maxf(size.y, size.x)
			return c
		BodyShape.CYLINDER:
			var cy := CylinderMesh.new()
			cy.top_radius = size.x * 0.5
			cy.bottom_radius = size.x * 0.5
			cy.height = size.y
			return cy
	var b := BoxMesh.new()
	b.size = size
	return b


func _build_body() -> void:
	var e := extents()
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	_material = StandardMaterial3D.new()
	_material.albedo_color = color
	_material.emission_enabled = true
	_material.emission = Color.BLACK
	var body := MeshInstance3D.new()
	body.mesh = make_mesh(body_shape, body_size)
	body.material_override = _material
	body.position.y = e.y * 0.5
	visual.add_child(body)
	# Snout and eyes so facing (and therefore telegraphs) read clearly.
	add_visual_box(Vector3(e.x * 0.4, e.y * 0.25, 0.2), Vector3(0, e.y * 0.5, -e.z * 0.5 - 0.08), color.darkened(0.45))
	var eye := Vector3(0.12, 0.12, 0.06)
	add_visual_box(eye, Vector3(-e.x * 0.22, e.y * 0.78, -e.z * 0.5 + 0.02), Color.WHITE)
	add_visual_box(eye, Vector3(e.x * 0.22, e.y * 0.78, -e.z * 0.5 + 0.02), Color.WHITE)

	var cs := CollisionShape3D.new()
	cs.shape = make_shape(body_shape, body_size)
	cs.position.y = e.y * 0.5
	add_child(cs)

	# Silk web around the feet, shown while rooted.
	_web = Node3D.new()
	_web.visible = false
	visual.add_child(_web)
	var silk := StandardMaterial3D.new()
	silk.albedo_color = Color(1, 1, 1, 0.8)
	silk.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i: int in 3:
		var strand := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.05, 0.05, maxf(e.x, e.z) * 1.6)
		strand.mesh = box
		strand.material_override = silk
		strand.position.y = 0.1
		strand.rotation.y = PI * float(i) / 3.0
		_web.add_child(strand)

	# Ice block encasing the body (snout included), shown while frozen.
	ice_block = MeshInstance3D.new()
	ice_block.name = "IceBlock"
	var ice_mesh := BoxMesh.new()
	ice_mesh.size = Vector3(e.x + 0.3, e.y + 0.25, e.z + 0.5)
	ice_block.mesh = ice_mesh
	var ice := StandardMaterial3D.new()
	ice.albedo_color = Color(0.7, 0.9, 1.0, 0.35)
	ice.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice.emission_enabled = true
	ice.emission = Color(0.2, 0.45, 0.7)
	ice.roughness = 0.05
	ice.metallic_specular = 1.0
	ice.cull_mode = BaseMaterial3D.CULL_DISABLED
	ice_block.material_override = ice
	ice_block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ice_block.position = Vector3(0, (e.y + 0.25) * 0.5, -0.1)
	ice_block.visible = false
	visual.add_child(ice_block)


func add_visual_box(size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mi.material_override = mat
	mi.position = pos
	visual.add_child(mi)
	return mi


## Creates an enemy attack HitBox (box shape, hits the player). Starts inactive.
func make_hit_box(box_name: String, size: Vector3, offset: Vector3, damage: float, knockback: float, knockback_up: float = 3.0) -> HitBox:
	var hb := HitBox.new()
	hb.name = box_name
	hb.collision_mask = Layers.PLAYER_HURTBOX
	hb.damage = damage
	hb.knockback = knockback
	hb.knockback_up = knockback_up
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = offset
	hb.add_child(cs)
	add_child(hb)
	return hb


## Creates a weak-spot HurtBox (extra damage, marked critical).
func make_weak_spot(size: Vector3, offset: Vector3, multiplier: float) -> HurtBox:
	var hb := HurtBox.new()
	hb.name = "WeakSpot"
	hb.collision_layer = Layers.ENEMY_HURTBOX
	hb.health = health
	hb.incoming_modifier = _modify_incoming
	hb.damage_multiplier = multiplier
	hb.is_weak_spot = true
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = offset
	hb.add_child(cs)
	add_child(hb)
	return hb


func _physics_process(delta: float) -> void:
	_age += delta
	_update_visuals(delta)
	if health.is_dead:
		return
	if global_position.y < KILL_PLANE_Y:
		health.apply_damage(DamageInfo.create(health.current + 1.0, global_position))
		return
	_update_burn(delta)
	_update_statuses(delta)
	target = _resolve_target()

	# The AI runs on its own clock: chill slows telegraphs and turning as well
	# as movement; freeze and stagger stop it entirely.
	var ai_delta := delta * ai_speed()
	state_time += ai_delta
	if is_disabled():
		desired_velocity = Vector3.ZERO
		_was_disabled = true
	elif _was_disabled:
		_was_disabled = false
		enter_state(_state_after_flinch() if aware else _calm_state())
	elif state == FLINCH:
		desired_velocity = Vector3.ZERO
		if state_time >= flinch_time:
			enter_state(_state_after_flinch())
	elif not aware:
		_tick_awareness(ai_delta)
	elif _should_give_up(ai_delta):
		enter_state(RETURN_HOME)
	else:
		_tick_state(ai_delta)

	_move_velocity = _move_velocity.move_toward(desired_velocity, acceleration * delta)
	_knockback = _knockback.move_toward(Vector3.ZERO, 25.0 * delta)
	var m := move_multiplier()
	var kb := 0.0 if is_frozen() or is_rooted() else 1.0
	velocity.x = _move_velocity.x * m + _knockback.x * kb
	velocity.z = _move_velocity.z * m + _knockback.z * kb
	if flying and not is_frozen():
		velocity.y = _move_velocity.y * m
	else:
		velocity.y -= gravity * delta
	move_and_slide()
	_after_move(delta)


func enter_state(new_state: StringName) -> void:
	state = new_state
	state_time = 0.0
	telegraph = 0.0
	visual_scale = Vector3.ONE
	visual_pitch = 0.0
	visual_yaw = 0.0
	visual_offset = Vector3.ZERO
	state_log.append("%s@%.2f" % [new_state, _age])
	_on_enter_awareness_state(new_state)
	_on_enter_state(new_state)


## Skip acceleration (charges, lunges).
func snap_velocity(v: Vector3) -> void:
	desired_velocity = v
	_move_velocity = v


func face_toward(point: Vector3, delta: float, speed_deg: float = -1.0) -> void:
	var to := point - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return
	var speed := deg_to_rad(turn_speed_deg if speed_deg < 0.0 else speed_deg)
	rotation.y = rotate_toward(rotation.y, atan2(-to.x, -to.z), speed * delta)


func forward() -> Vector3:
	var f := -global_basis.z
	f.y = 0.0
	return f.normalized()


func has_target() -> bool:
	return target != null and is_instance_valid(target)


func target_position() -> Vector3:
	return target.global_position if has_target() else global_position


func distance_to_target() -> float:
	if not has_target():
		return INF
	var d := target.global_position - global_position
	d.y = 0.0
	return d.length()


func direction_to_target() -> Vector3:
	if not has_target():
		return forward()
	var d := target.global_position - global_position
	d.y = 0.0
	return d.normalized() if d.length_squared() > 0.0001 else forward()


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP * extents().y * 0.5


## The ground (WORLD) below `p`, or `p` itself over a void.
func ground_point(p: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 4.0, p + Vector3.DOWN * 30.0, Layers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return p if hit.is_empty() else (hit["position"] as Vector3)


## Height of the feet above the ground below (hover_height over a void, so
## flyers just hold their height there).
func altitude() -> float:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.1, global_position + Vector3.DOWN * 30.0, Layers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hover_height if hit.is_empty() else global_position.y - (hit["position"] as Vector3).y


## Where the target will be in `seconds` if it keeps its ground velocity.
func lead_target(seconds: float) -> Vector3:
	var p := target_position()
	var body := target as CharacterBody3D
	if body != null:
		var v := body.velocity
		v.y = 0.0
		p += v * seconds
	return p


## Vertical speed that eases a flyer to `height` above the ground.
func hover_velocity(height: float) -> float:
	return clampf((height - altitude()) * 3.0, -climb_speed, climb_speed)


func apply_burn(dps: float, duration: float, source: Weapon) -> void:
	_burn_dps = maxf(_burn_dps, dps)
	_burn_left = maxf(_burn_left, duration)
	_burn_source = source


func _update_burn(delta: float) -> void:
	if _burn_left <= 0.0:
		return
	_burn_left -= delta
	_burn_tick += delta
	if _burn_tick >= BURN_TICK:
		_burn_tick -= BURN_TICK
		var info := DamageInfo.create(_burn_dps * BURN_TICK, global_position)
		info.is_dot = true
		if is_instance_valid(_burn_source):
			info.source_weapon = _burn_source
		health.apply_damage(info)
	if _burn_left <= 0.0:
		_burn_dps = 0.0


## The Enemy a hurtbox belongs to, or null (crates, the player, decoys).
static func from_hurt_box(hb: HurtBox) -> Enemy:
	if hb == null or hb.health == null:
		return null
	return hb.health.get_parent() as Enemy


## Every living enemy within `radius` of `center`.
static func in_radius(tree: SceneTree, center: Vector3, radius: float) -> Array[Enemy]:
	var out: Array[Enemy] = []
	for n: Node in tree.get_nodes_in_group(&"enemies"):
		var e := n as Enemy
		if e != null and not e.health.is_dead and e.get_aim_point().distance_to(center) <= radius + maxf(e.extents().x, e.extents().z) * 0.5:
			out.append(e)
	return out


# --- Targeting ----------------------------------------------------------------

## The closest lure (group "lures", property lure_radius) in range wins over
## the player.
func _resolve_target() -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for n: Node in get_tree().get_nodes_in_group(&"lures"):
		var lure := n as Node3D
		if lure == null or not (lure.get(&"lure_radius") is float):
			continue
		var d := lure.global_position.distance_to(global_position)
		if d <= float(lure.get(&"lure_radius")) and d < best_dist:
			best = lure
			best_dist = d
	if best != null:
		return best
	var p: Node3D = target if target != null and is_instance_valid(target) and target.is_in_group(&"player") else get_tree().get_first_node_in_group(&"player") as Node3D
	# A dead player is no target: enemies stop attacking the corpse during the
	# respawn delay (placed enemies are then reset by LevelRoot).
	if p is Player and (p as Player).is_dead:
		return null
	return p


# --- Awareness ------------------------------------------------------------------
# Unaware enemies run rest / wander / patrol / suspicious / investigate / alert /
# return_home here instead of _tick_state. Noticing ends in `idle`, which every
# enemy hands to combat. Aware enemies with a leash or forget_time walk home
# (return_home) and become unaware again.

## Wave enemies: start aware and never leash or forget (they have no home).
## Call before adding to the tree.
func make_always_aware() -> void:
	starts_aware = true
	leash_radius = 0.0
	forget_time = 0.0


func is_awareness_state(s: StringName) -> bool:
	return s in [REST, WANDER, PATROL, SUSPICIOUS, INVESTIGATE, ALERT, RETURN_HOME]


## Notice at once (damage, point blank): no alert pop. `spread` wakes neighbours.
func become_aware(spread: bool = true) -> void:
	if aware or health.is_dead:
		return
	aware = true
	suspicion = 1.0
	unseen_time = 0.0
	_alert_delay = -1.0
	enter_state(&"idle")
	if spread:
		_alert_neighbours()


## Another enemy's alert reached this one: alert after `delay`, without spreading.
func receive_alert(from: Enemy, delay: float) -> void:
	if aware or health.is_dead or state == ALERT or _alert_delay >= 0.0:
		return
	alerted_by = from
	alerted_at = _age
	_alert_delay = delay


func is_alert_pending() -> bool:
	return _alert_delay >= 0.0


## Called by NoiseEvent.emit(). Unaware enemies in range go to investigate the spot.
func hear(at: Vector3, radius: float) -> bool:
	if aware or health.is_dead or state == ALERT or is_disabled():
		return false
	if global_position.distance_to(at) > radius + hearing_range:
		return false
	investigate_point = at
	enter_state(INVESTIGATE)
	return true


## Suspicion gained per second while seeing someone `distance` metres away.
func notice_rate(distance: float) -> float:
	var t := clampf(distance / maxf(sight_range, 0.01), 0.0, 1.0)
	return lerpf(NEAR_NOTICE_BOOST, FAR_NOTICE_FACTOR, t) / maxf(notice_time, 0.01)


func eye_point() -> Vector3:
	return global_position + Vector3.UP * extents().y * 0.8


func has_line_of_sight(point: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(eye_point(), point, Layers.WORLD)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()




## Updates sees_target / los_* for `target`. `cone` false = any direction.
func perceive(range_limit: float, cone: bool) -> bool:
	sees_target = false
	los_checked = false
	los_blocked = false
	perceived_distance = INF
	if not has_target():
		return false
	var p := target.global_position + Vector3.UP * 0.9
	if target.has_method(&"get_aim_point"):
		p = target.call(&"get_aim_point")
	var to := p - eye_point()
	perceived_distance = to.length()
	if perceived_distance > range_limit:
		return false
	if cone and perceived_distance > point_blank_range:
		var flat := Vector3(to.x, 0.0, to.z)
		if flat.length_squared() > 0.0001 and rad_to_deg(forward().angle_to(flat.normalized())) > sight_fov_deg * 0.5:
			return false
	los_checked = true
	los_blocked = not has_line_of_sight(p)
	sees_target = not los_blocked
	if sees_target:
		last_seen_position = target.global_position
	return sees_target


## Where an unaware enemy settles after losing interest.
func _calm_state() -> StringName:
	if not patrol_points.is_empty():
		return PATROL
	if _flat_distance(global_position, home_position) > maxf(wander_radius, 1.5):
		return RETURN_HOME
	return REST


func _tick_awareness(delta: float) -> void:
	if _alert_delay >= 0.0:
		_alert_delay -= delta
		if _alert_delay < 0.0:
			_begin_alert(false)
	if state == ALERT:
		_stop()
		if has_target():
			face_toward(target_position(), delta, 720.0)
		visual_scale = ALERT_POP_SCALE if state_time < alert_time * 0.35 else Vector3.ONE
		if state_time >= alert_time:
			aware = true
			suspicion = 1.0
			unseen_time = 0.0
			enter_state(&"idle")
		return

	# Heading home only point-blank contact counts (stops leash ping-pong).
	var sees := perceive(point_blank_range, false) if state == RETURN_HOME else perceive(sight_range, true)
	if sees and perceived_distance <= point_blank_range:
		become_aware()
		return
	if sees:
		unseen_time = 0.0
		suspicion = minf(1.0, suspicion + notice_rate(perceived_distance) * delta)
	else:
		unseen_time += delta
		suspicion = maxf(0.0, suspicion - suspicion_decay * delta)
	if suspicion >= 1.0:
		_begin_alert(true)
		return
	if sees and state != SUSPICIOUS and state != RETURN_HOME:
		enter_state(SUSPICIOUS)

	var walk := move_speed * unaware_speed_factor
	match state:
		REST:
			_stop()
			_idle_flavour(delta)
			if patrol_points.is_empty() and wander_radius <= 0.0:
				rotation.y = rotate_toward(rotation.y, home_yaw, deg_to_rad(turn_speed_deg) * 0.5 * delta)
			elif state_time >= _rest_duration:
				enter_state(WANDER if patrol_points.is_empty() else PATROL)
		WANDER:
			if _walk_to(_walk_goal, walk, delta) or state_time > _walk_limit:
				enter_state(REST)
		PATROL:
			if _walk_to(_walk_goal, walk, delta) or state_time > _walk_limit:
				_patrol_index = (_patrol_index + 1) % patrol_points.size()
				enter_state(REST)
		SUSPICIOUS:
			_stop()
			face_toward(last_seen_position, delta, turn_speed_deg * 0.5)
			if suspicion <= 0.0:
				enter_state(_calm_state())
			elif unseen_time > 1.0:
				investigate_point = last_seen_position
				enter_state(INVESTIGATE)
		INVESTIGATE:
			if _look_left < 0.0:
				if _walk_to(investigate_point, walk, delta) or state_time > _walk_limit:
					_look_left = investigate_time
			else:
				_stop()
				rotation.y += deg_to_rad(turn_speed_deg) * 0.25 * delta * signf(sin(state_time * 1.3) + 0.01)
				_look_left -= delta
				if _look_left <= 0.0:
					enter_state(_calm_state())
		RETURN_HOME:
			var speed := move_speed * RETURN_SPEED_FACTOR
			if _walk_to(home_position, speed, delta) or state_time > _walk_limit:
				health.heal(health.max_health)
				enter_state(PATROL if not patrol_points.is_empty() else REST)
		_:
			# A subclass state while unaware (e.g. resumed after a freeze).
			enter_state(_calm_state())


func _begin_alert(spread: bool) -> void:
	_alert_delay = -1.0
	suspicion = 1.0
	enter_state(ALERT)
	if spread:
		_alert_neighbours()


## Wakes unaware enemies within alert_radius that can see this one. The woken
## ones alert after a staggered delay and do not pass it on.
func _alert_neighbours() -> void:
	if health.current <= 0.0:
		return
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e := n as Enemy
		if e == null or e == self or e.aware or e.health.is_dead:
			continue
		if e.global_position.distance_to(global_position) > alert_radius:
			continue
		var q := PhysicsRayQueryParameters3D.create(eye_point(), e.eye_point(), Layers.WORLD)
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			continue
		e.receive_alert(self, rng.randf_range(GROUP_ALERT_DELAY_MIN, GROUP_ALERT_DELAY_MAX))


## Aware enemies give up when leashed or when they lost their target too long.
func _should_give_up(delta: float) -> bool:
	if leash_radius > 0.0 and _flat_distance(global_position, home_position) > leash_radius:
		return true
	if forget_time > 0.0:
		if perceive(sight_range * AWARE_SIGHT_FACTOR, false):
			unseen_time = 0.0
		else:
			unseen_time += delta
			if unseen_time >= forget_time:
				return true
	return false


func _on_enter_awareness_state(s: StringName) -> void:
	match s:
		REST:
			_rest_duration = rng.randf_range(rest_time_min, rest_time_max)
		WANDER:
			var a := rng.randf() * TAU
			var r := sqrt(rng.randf()) * wander_radius
			_walk_goal = home_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
			_walk_limit = _walk_timeout(_walk_goal, move_speed * unaware_speed_factor)
		PATROL:
			_walk_goal = patrol_points[_patrol_index]
			_walk_limit = _walk_timeout(_walk_goal, move_speed * unaware_speed_factor)
		INVESTIGATE:
			_look_left = -1.0
			_walk_limit = _walk_timeout(investigate_point, move_speed * unaware_speed_factor)
		RETURN_HOME:
			aware = false
			suspicion = 0.0
			unseen_time = 0.0
			_alert_delay = -1.0
			_walk_limit = _walk_timeout(home_position, move_speed * RETURN_SPEED_FACTOR) + 5.0


## Steers towards `point` (flat). Returns true once there. Flyers hold hover height.
func _walk_to(point: Vector3, speed: float, delta: float) -> bool:
	var to := point - global_position
	to.y = 0.0
	if to.length() <= ARRIVE_DISTANCE:
		_stop()
		return true
	face_toward(point, delta)
	desired_velocity = to.normalized() * speed
	desired_velocity.y = hover_velocity(hover_height) if flying else 0.0
	return false


## Give up on a walk after twice the expected time (stuck on a wall).
func _walk_timeout(point: Vector3, speed: float) -> float:
	return _flat_distance(global_position, point) / maxf(speed, 0.1) * 2.0 + 3.0


func _stop() -> void:
	desired_velocity = Vector3(0.0, hover_velocity(hover_height) if flying else 0.0, 0.0)


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# --- Status effects -------------------------------------------------------------

func is_frozen() -> bool:
	return frozen_left > 0.0


func is_rooted() -> bool:
	return rooted_left > 0.0


func is_staggered() -> bool:
	return staggered_left > 0.0


func is_exposed() -> bool:
	return exposed_left > 0.0


## Frozen or staggered: the AI is paused and attacks are cancelled.
func is_disabled() -> bool:
	return is_frozen() or is_staggered()


## Speed of the AI clock (telegraphs, turning, state timers).
func ai_speed() -> float:
	return 0.0 if is_disabled() else 1.0 - chill * CHILL_MAX_SLOW


func move_multiplier() -> float:
	return 0.0 if is_disabled() or is_rooted() else ai_speed()


## Adds chill (0..1). At 1 the enemy freezes for `freeze_duration`.
func add_chill(amount: float, freeze_duration: float) -> void:
	if is_frozen() or status_resistance <= 0.0 or health.is_dead:
		return
	chill = minf(1.0, chill + amount * status_resistance)
	_chill_hold = CHILL_DECAY_DELAY
	if chill >= 1.0:
		freeze(freeze_duration)


func freeze(duration: float) -> void:
	if status_resistance <= 0.0 or health.is_dead:
		return
	chill = 1.0
	frozen_left = maxf(frozen_left, duration * status_resistance)
	_interrupt()
	GameFeel.impact(get_aim_point(), FREEZE_COLOR, extents().length() * 1.3, 0.25)


func root(duration: float) -> void:
	if status_resistance <= 0.0 or health.is_dead:
		return
	rooted_left = maxf(rooted_left, duration * status_resistance)


## Interrupts the current attack. Resistance shortens it.
func stagger(duration: float) -> void:
	if status_resistance <= 0.0 or health.is_dead:
		return
	staggered_left = maxf(staggered_left, duration * status_resistance)
	_interrupt()


## Takes EXPOSED_DAMAGE_MULTIPLIER damage for a while. Not affected by resistance.
func expose(duration: float) -> void:
	exposed_left = maxf(exposed_left, duration)


## Stacking damage over time. Contagious poison spreads to nearby enemies on death.
func add_poison(stacks: int, source: Weapon, contagious: bool = false) -> void:
	if health.is_dead or stacks <= 0:
		return
	poison_stacks = mini(POISON_MAX_STACKS, poison_stacks + stacks)
	_poison_left = POISON_DURATION
	_poison_source = source
	_poison_contagious = _poison_contagious or contagious


func _interrupt() -> void:
	for child: Node in get_children():
		if child is HitBox:
			(child as HitBox).active = false
	snap_velocity(Vector3.ZERO)
	telegraph = 0.0
	visual_scale = Vector3.ONE
	visual_pitch = 0.0
	visual_yaw = 0.0
	visual_offset = Vector3.ZERO


func _update_statuses(delta: float) -> void:
	if frozen_left > 0.0:
		frozen_left -= delta
		if frozen_left <= 0.0:
			chill = 0.0
			GameFeel.impact(get_aim_point(), FREEZE_COLOR, extents().length() * 1.1, 0.2)
	else:
		_chill_hold -= delta
		if _chill_hold <= 0.0:
			chill = maxf(0.0, chill - CHILL_DECAY_PER_SEC * delta)
	rooted_left = maxf(0.0, rooted_left - delta)
	staggered_left = maxf(0.0, staggered_left - delta)
	exposed_left = maxf(0.0, exposed_left - delta)
	if poison_stacks > 0:
		_poison_left -= delta
		_poison_tick += delta
		if _poison_tick >= POISON_TICK:
			_poison_tick -= POISON_TICK
			var info := DamageInfo.create(poison_stacks * POISON_DPS_PER_STACK * POISON_TICK, global_position)
			info.is_dot = true
			if is_instance_valid(_poison_source):
				info.source_weapon = _poison_source
			health.apply_damage(info)
		if _poison_left <= 0.0:
			poison_stacks = 0
			_poison_contagious = false


## Frozen and exposed enemies take extra damage from every source.
func _modify_incoming(info: DamageInfo) -> void:
	if is_frozen():
		info.amount *= FROZEN_DAMAGE_MULTIPLIER
	if is_exposed():
		info.amount *= EXPOSED_DAMAGE_MULTIPLIER


func _spread_poison() -> void:
	if poison_stacks <= 0 or not _poison_contagious:
		return
	var spread := maxi(1, floori(poison_stacks * 0.5))
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e := n as Enemy
		if e != null and e != self and e.global_position.distance_to(global_position) <= CONTAGION_RADIUS:
			e.add_poison(spread, _poison_source, true)
	GameFeel.impact(get_aim_point(), POISON_COLOR, CONTAGION_RADIUS * 2.0, 0.35)


func status_summary() -> String:
	var parts := PackedStringArray()
	if is_frozen():
		parts.append("FROZEN %.1f" % frozen_left)
	elif chill > 0.01:
		parts.append("chill %d%%" % roundi(chill * 100.0))
	if is_rooted():
		parts.append("rooted %.1f" % rooted_left)
	if is_staggered():
		parts.append("stagger %.1f" % staggered_left)
	if is_exposed():
		parts.append("exposed %.1f" % exposed_left)
	if poison_stacks > 0:
		parts.append("poison x%d" % poison_stacks)
	return " ".join(parts)


func _on_damaged(amount: float, info: DamageInfo) -> void:
	# Getting hurt wakes an enemy at once, except by neutral hazards or stray DoT.
	if not aware and not info.from_hazard and (not info.is_dot or is_instance_valid(info.source_weapon)):
		become_aware()
	if info.is_dot:
		return
	_flash = 1.0
	var away := global_position - info.source_position
	away.y = 0.0
	if away.length_squared() > 0.0001:
		_knockback += away.normalized() * info.knockback * (1.0 - knockback_resistance)
	if info.knockback_up > 0.0 and is_on_floor():
		velocity.y = info.knockback_up * (1.0 - knockback_resistance)
	GameFeel.damage_number(get_aim_point() + Vector3.UP * extents().y * 0.5, amount, info.is_critical)
	if flinch_on_hit and not health.is_dead and not is_disabled() and _can_flinch():
		enter_state(FLINCH)


func _on_died(info: DamageInfo) -> void:
	_spread_poison()
	if info != null and is_instance_valid(info.source_weapon):
		info.source_weapon.add_xp(xp_value)
	remove_from_group(&"aim_targets")
	remove_from_group(&"enemies")
	collision_layer = 0
	collision_mask = Layers.WORLD
	desired_velocity = Vector3.ZERO
	_move_velocity = Vector3.ZERO
	for child: Node in get_children():
		if child is HitBox:
			(child as HitBox).active = false
		if child is HurtBox:
			(child as HurtBox).set_deferred(&"monitorable", false)
	_label.visible = false
	_on_death()
	died.emit(self)
	GameFeel.impact(get_aim_point(), color, extents().length() * 1.2, 0.3)
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3(1.3, 0.05, 1.3), 0.25).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _update_visuals(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 8.0)
	var glow := TELEGRAPH_COLOR * telegraph + Color.WHITE * _flash
	if _burn_left > 0.0:
		glow += BURN_COLOR * (0.5 + 0.3 * sin(_age * 20.0))
	if poison_stacks > 0:
		glow += POISON_COLOR * (0.25 + 0.04 * poison_stacks + 0.15 * sin(_age * 6.0))
	if is_exposed():
		glow += EXPOSED_COLOR * (0.3 + 0.2 * sin(_age * 10.0))
	if is_frozen():
		glow += FREEZE_COLOR * 0.5
	elif chill > 0.0:
		glow += CHILL_GLOW * chill * (0.6 + 0.15 * sin(_age * 8.0))
	_material.emission = glow
	_material.albedo_color = color.lerp(FREEZE_COLOR, 0.85 if is_frozen() else chill * 0.75)
	_web.visible = is_rooted()
	ice_block.visible = is_frozen() and not health.is_dead
	visual.rotation.x = sin(_age * 30.0) * 0.06 if is_staggered() else visual_pitch
	var settle := 1.0 - exp(-12.0 * delta)
	visual.rotation.y = lerp_angle(visual.rotation.y, visual_yaw, settle)
	visual.position = visual.position.lerp(visual_offset, settle)
	if not health.is_dead:
		visual.scale = visual.scale.lerp(visual_scale, 1.0 - exp(-20.0 * delta))
	if _label.visible:
		_label.text = "%s\n%s %.1fs\n%d/%d hp\n%s" % [display_name, state, state_time, ceili(health.current), ceili(health.max_health), status_summary()]


func _on_show_boxes_changed(enabled: bool) -> void:
	_label.visible = enabled and not health.is_dead


func _on_show_ai_changed(enabled: bool) -> void:
	if enabled and ai_view == null:
		ai_view = AiDebugView.attach(self)
	elif not enabled and ai_view != null:
		ai_view.queue_free()
		ai_view = null


## Seconds since spawn (the clock state_log, alerted_at use).
func age_seconds() -> float:
	return _age


# --- Virtuals -----------------------------------------------------------------

## Build hitboxes, weak spots and extra visuals.
func _setup() -> void:
	pass


func _tick_state(_delta: float) -> void:
	pass


func _on_enter_state(_new_state: StringName) -> void:
	pass


func _after_move(_delta: float) -> void:
	pass


func _can_flinch() -> bool:
	return true


func _state_after_flinch() -> StringName:
	return &"idle"


func _on_death() -> void:
	pass


## Called every AI frame while resting unaware. Pure visual fidget: drive
## visual_pitch / visual_yaw / visual_scale / visual_offset (all reset when the
## state changes). Never activate hitboxes, never use the telegraph glow or a
## forward lunge squash (those mean "attack coming").
func _idle_flavour(_delta: float) -> void:
	pass
