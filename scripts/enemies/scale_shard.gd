class_name ScaleShard
extends Node3D
## Straight-flying brass scale (Brass Pangolin volley). Sweeps a ray each frame:
## WORLD stops it, a hurtbox on `hit_mask` takes `damage` and stops it (a hurtbox
## that refuses the hit, e.g. a dodging player, lets it fly on). Passing through a
## REFLECTOR area sends it back at `source`, now hitting enemies and crediting the
## reflecting weapon.

const COLOR := Color(0.95, 0.85, 0.5)
const MAX_RANGE := 30.0

var direction: Vector3 = Vector3.FORWARD
var speed: float = 15.0
var damage: float = 8.0
var knockback: float = 5.0
var max_range: float = MAX_RANGE
var hit_mask: int = Layers.PLAYER_HURTBOX
var source: Node3D = null
var reflected: bool = false

var _travelled: float = 0.0
var _exclude: Array[RID] = []
var _mat: StandardMaterial3D
var _reflect_weapon: Weapon = null


static func launch(thrower: Node3D, from: Vector3, dir: Vector3, shard_speed: float, shard_damage: float) -> ScaleShard:
	var shard := ScaleShard.new()
	shard.direction = dir.normalized()
	shard.speed = shard_speed
	shard.damage = shard_damage
	shard.source = thrower
	shard.position = from
	thrower.get_parent().add_child(shard)
	return shard


func _ready() -> void:
	add_to_group(LobProjectile.GROUP)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.06, 0.5)
	mesh.mesh = box
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = COLOR
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.45, 0.15) * 0.8
	mesh.material_override = _mat
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	_orient()


func _orient() -> void:
	look_at(global_position + direction, Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT)


func _physics_process(delta: float) -> void:
	var from := global_position
	var to := from + direction * speed * delta
	if _sweep(from, to):
		return
	global_position = to
	_travelled += speed * delta
	if not reflected:
		_check_reflector()
	if _travelled >= max_range:
		queue_free()


## Returns true if the shard died.
func _sweep(from: Vector3, to: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	for _i: int in 4:
		var q := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD | hit_mask, _exclude)
		q.collide_with_areas = true
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return false
		var hb := hit["collider"] as HurtBox
		if hb == null:
			_die(hit["position"])
			return true
		_exclude.append(hb.get_rid())
		if hb.receive(_make_damage(hit["position"])):
			_die(hit["position"])
			return true
	return false


func _make_damage(at: Vector3) -> DamageInfo:
	var from := at - direction
	var info: DamageInfo
	if reflected and is_instance_valid(_reflect_weapon):
		info = _reflect_weapon.make_damage(damage, from)
		info.knockback = knockback
	else:
		info = DamageInfo.create(damage, from, knockback)
	info.knockback_up = 2.0
	return info


func _check_reflector() -> void:
	var params := PhysicsPointQueryParameters3D.new()
	params.position = global_position
	params.collision_mask = Layers.REFLECTOR
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var hits := get_world_3d().direct_space_state.intersect_point(params, 1)
	if hits.is_empty():
		return
	var wall := (hits[0]["collider"] as Node).get_parent()
	reflect(float(wall.get(&"reflect_damage")), wall.get(&"weapon") as Weapon)


## Send the shard back at its thrower as a player-side attack.
func reflect(new_damage: float, weapon: Weapon) -> void:
	reflected = true
	_reflect_weapon = weapon
	damage = new_damage
	hit_mask = Layers.ENEMY_HURTBOX
	_exclude.clear()
	_travelled = 0.0
	if source != null and is_instance_valid(source):
		var aim := (source as Enemy).get_aim_point() if source is Enemy else source.global_position
		direction = (aim - global_position).normalized()
	else:
		direction = -direction
	_orient()
	_mat.emission = LobProjectile.REFLECTED_COLOR * 0.8
	GameFeel.impact(global_position, LobProjectile.REFLECTED_COLOR, 0.8, 0.12)


func _die(at: Vector3) -> void:
	GameFeel.impact(at, COLOR, 0.4, 0.08)
	queue_free()
