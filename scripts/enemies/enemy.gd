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

	_setup()
	enter_state(&"idle")


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
	state_time += delta
	_update_burn(delta)
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(&"player") as Node3D

	if state == FLINCH:
		desired_velocity = Vector3.ZERO
		if state_time >= flinch_time:
			enter_state(_state_after_flinch())
	else:
		_tick_state(delta)

	_move_velocity = _move_velocity.move_toward(desired_velocity, acceleration * delta)
	_knockback = _knockback.move_toward(Vector3.ZERO, 25.0 * delta)
	velocity.x = _move_velocity.x + _knockback.x
	velocity.z = _move_velocity.z + _knockback.z
	velocity.y -= gravity * delta
	move_and_slide()
	_after_move(delta)


func enter_state(new_state: StringName) -> void:
	state = new_state
	state_time = 0.0
	telegraph = 0.0
	visual_scale = Vector3.ONE
	state_log.append("%s@%.2f" % [new_state, _age])
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


func _on_damaged(amount: float, info: DamageInfo) -> void:
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
	if flinch_on_hit and not health.is_dead and _can_flinch():
		enter_state(FLINCH)


func _on_died(info: DamageInfo) -> void:
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
	_material.emission = glow
	if not health.is_dead:
		visual.scale = visual.scale.lerp(visual_scale, 1.0 - exp(-20.0 * delta))
	if _label.visible:
		_label.text = "%s\n%s %.1fs\n%d/%d hp" % [display_name, state, state_time, ceili(health.current), ceili(health.max_health)]


func _on_show_boxes_changed(enabled: bool) -> void:
	_label.visible = enabled and not health.is_dead


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
