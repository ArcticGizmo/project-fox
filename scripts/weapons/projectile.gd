class_name Projectile
extends Node3D
## Raycast-swept projectile (no tunnelling at any speed) with optional homing,
## pierce and a hit radius for forgiving hits.

var direction: Vector3 = Vector3.FORWARD
var speed: float = 20.0
var damage: float = 10.0
var lifetime: float = 2.0
var radius: float = 0.2
var pierce_left: int = 0
var homing_deg_per_sec: float = 0.0
var homing_target: Node3D = null
## Seconds before homing kicks in (lets swarms fan out first).
var homing_delay: float = 0.0
var hit_mask: int = Layers.WORLD | Layers.ENEMY_HURTBOX
var weapon: Weapon = null
var color: Color = Color.WHITE
var size: Vector3 = Vector3(0.15, 0.15, 0.45)

var _age: float = 0.0
var _hit_entities: Dictionary = {}
var _exclude: Array[RID] = []
var _sphere: SphereShape3D


func _ready() -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_sphere = SphereShape3D.new()
	_sphere.radius = radius
	_orient()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	_update_homing(delta)
	var from := global_position
	var to := from + direction * speed * delta
	if _sweep(from, to):
		return
	global_position = to
	_orient()
	if radius > 0.0 and _overlap(to):
		return


func _update_homing(delta: float) -> void:
	if homing_deg_per_sec <= 0.0 or _age < homing_delay:
		return
	if homing_target == null or not is_instance_valid(homing_target) or not homing_target.is_in_group(&"aim_targets"):
		homing_target = _acquire_target()
		if homing_target == null:
			return
	var desired := (AimAssist.get_aim_point(homing_target) - global_position).normalized()
	var angle := direction.angle_to(desired)
	if angle < 0.0001:
		return
	var max_step := deg_to_rad(homing_deg_per_sec) * delta
	direction = direction.slerp(desired, minf(1.0, max_step / angle)).normalized()


func _acquire_target() -> Node3D:
	return AimAssist.pick_target(global_position, direction, AimAssist.nodes_in_group(get_tree(), &"aim_targets"), 45.0, 40.0)


## Returns true if the projectile died.
func _sweep(from: Vector3, to: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	for _i: int in 8:
		var q := PhysicsRayQueryParameters3D.create(from, to, hit_mask, _exclude)
		q.collide_with_areas = true
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return false
		var hb := hit["collider"] as HurtBox
		if hb == null:
			_die(hit["position"])
			return true
		_exclude.append(hb.get_rid())
		if _hit(hb):
			return true
	return false


func _overlap(at: Vector3) -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _sphere
	params.transform = Transform3D(Basis.IDENTITY, at)
	params.collision_mask = hit_mask & ~Layers.WORLD
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.exclude = _exclude
	for result: Dictionary in get_world_3d().direct_space_state.intersect_shape(params, 8):
		var hb := result["collider"] as HurtBox
		if hb == null:
			continue
		_exclude.append(hb.get_rid())
		if _hit(hb):
			return true
	return false


## Returns true if the projectile died.
func _hit(hb: HurtBox) -> bool:
	var key := hb.entity_id()
	if _hit_entities.has(key):
		return false
	_hit_entities[key] = true
	var info := DamageInfo.create(damage, global_position - direction, 0.0)
	if weapon != null and is_instance_valid(weapon):
		info = weapon.make_damage(damage, global_position - direction)
	if not hb.receive(info):
		return false
	GameFeel.impact(global_position, color, 0.5)
	if pierce_left <= 0:
		queue_free()
		return true
	pierce_left -= 1
	return false


func _die(at: Vector3) -> void:
	GameFeel.impact(at, color.darkened(0.3), 0.35)
	queue_free()


func _orient() -> void:
	if direction.length_squared() > 0.0001:
		look_at(global_position + direction, Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT)
