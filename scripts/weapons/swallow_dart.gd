class_name SwallowDart
extends Node3D
## A clockwork swallow (Clockwork Swallow weapon) that flies a curve around its
## target and strikes it from behind. Cubic Bezier: out to `side` from the
## muzzle, past the target, then back into it, so the hit lands on the side
## facing away from the shooter (frontal armour never sees it). The end point
## follows a live target. Sweeps a ray along the path: WORLD ends the flight,
## the first enemy hurtbox takes the hit.

## Landed on `enemy` (null for a non-enemy hurtbox), in its back or not.
signal struck(enemy: Enemy, from_behind: bool)

## Fraction of the shot distance the curve swings past the target.
const OVERSHOOT := 0.35
## Forgiveness radius for the hit sweep.
const HIT_RADIUS := 0.35

var weapon: Weapon
var target: Node3D = null
var end_point: Vector3 = Vector3.ZERO
## +1 curves right, -1 left (seen from the shooter).
var side: float = 1.0
var width: float = 4.0
var speed: float = 22.0
var damage: float = 10.0
var color: Color = Color(0.85, 0.3, 0.6)
## Damage multiplier when it hits an enemy in the back (1 = no bonus).
var back_multiplier: float = 1.0
## The enemy hit, and whether it was in the back (tests).
var hit_enemy: Enemy = null
var hit_from_behind: bool = false

var _start: Vector3
var _t: float = 0.0
var _duration: float = 1.0
var _sphere: SphereShape3D


func _ready() -> void:
	_start = global_position
	var flat := _target_point() - _start
	flat.y = 0.0
	_duration = maxf(0.25, (flat.length() * (1.0 + 2.0 * OVERSHOOT) + width) / speed)
	_sphere = SphereShape3D.new()
	_sphere.radius = HIT_RADIUS
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.1, 0.45)
	body.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.8
	body.material_override = mat
	add_child(body)
	var wings := MeshInstance3D.new()
	var wing_box := BoxMesh.new()
	wing_box.size = Vector3(0.6, 0.03, 0.14)
	wings.mesh = wing_box
	wings.material_override = mat
	wings.position.z = -0.05
	add_child(wings)


func _target_point() -> Vector3:
	if target != null and is_instance_valid(target) and target.is_in_group(&"aim_targets"):
		end_point = AimAssist.get_aim_point(target)
	return end_point


## Point on the curve at u in [0, 1].
func point_at(u: float) -> Vector3:
	var p3 := _target_point()
	var fwd := p3 - _start
	fwd.y = 0.0
	var dist := fwd.length()
	fwd = fwd / dist if dist > 0.01 else Vector3.FORWARD
	var right := fwd.cross(Vector3.UP)
	var p1 := _start + fwd * dist * 0.35 + right * side * width
	var p2 := p3 + fwd * maxf(3.0, dist * OVERSHOOT) + right * side * width * 0.3
	var v := 1.0 - u
	return _start * v * v * v + p1 * 3.0 * v * v * u + p2 * 3.0 * v * u * u + p3 * u * u * u


func _physics_process(delta: float) -> void:
	var from := global_position
	_t += delta
	var u := _t / _duration
	var to := point_at(minf(u, 1.0))
	if u > 1.0:
		# Past the end of the curve: carry on straight for a moment.
		to = from + (from - point_at(0.98)).normalized() * speed * delta
	if from.distance_squared_to(to) > 0.000001:
		look_at(to, Vector3.UP)
	if _sweep(from, to):
		return
	global_position = to
	if u > 1.3:
		queue_free()


## Returns true if the dart ended.
func _sweep(from: Vector3, to: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	var wall := space.intersect_ray(q)
	var reach := to if wall.is_empty() else (wall["position"] as Vector3)
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _sphere
	params.collision_mask = Layers.ENEMY_HURTBOX
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var dir := (to - from).normalized()
	var steps := maxi(1, ceili(from.distance_to(reach) / HIT_RADIUS))
	for i: int in steps + 1:
		params.transform = Transform3D(Basis.IDENTITY, from.lerp(reach, float(i) / steps))
		for r: Dictionary in space.intersect_shape(params, 4):
			var hb := r["collider"] as HurtBox
			if hb != null and _hit(hb, dir):
				return true
	if not wall.is_empty():
		GameFeel.impact(reach, color, 0.4)
		queue_free()
		return true
	return false


func _hit(hb: HurtBox, dir: Vector3) -> bool:
	var e := Enemy.from_hurt_box(hb)
	var flat_dir := Vector3(dir.x, 0.0, dir.z).normalized()
	# Swing past the target on the way out; only the return leg (heading back
	# toward the shooter) can strike it.
	if e != null and e == target and flat_dir.dot(_outward()) > 0.0:
		return false
	var at := hb.center()
	# The dart itself is the source, so armour judges the side it really came from.
	var from := global_position
	var info := weapon.make_damage(damage, from) if is_instance_valid(weapon) else DamageInfo.create(damage, from)
	var rel := from - e.global_position if e != null else Vector3.ZERO
	rel.y = 0.0
	var behind := e != null and e.forward().dot(rel) < 0.0
	if behind and back_multiplier > 1.0:
		info.amount *= back_multiplier
		info.is_critical = true
	if not hb.receive(info):
		return false
	hit_enemy = e
	hit_from_behind = behind
	struck.emit(e, behind)
	GameFeel.impact(at, color, 0.7)
	queue_free()
	return true


## Flat direction from the muzzle to the target.
func _outward() -> Vector3:
	var fwd := _target_point() - _start
	fwd.y = 0.0
	return fwd.normalized() if fwd.length_squared() > 0.0001 else Vector3.FORWARD
