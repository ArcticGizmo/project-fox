class_name Explosion
extends RefCounted
## Instant spherical area damage. Each entity is hit once, preferring a
## non-weak-spot hurtbox (area damage should not crit by accident).
## Every blast is also a NoiseEvent heard NOISE_BASE + radius * NOISE_PER_RADIUS away.

const NOISE_BASE := 8.0
const NOISE_PER_RADIUS := 3.0


## `make_info` is called once per hit entity and must return a fresh DamageInfo.
## Returns the number of entities hit.
static func detonate(world_node: Node3D, center: Vector3, radius: float, mask: int, make_info: Callable) -> int:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, center)
	params.collision_mask = mask
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var best: Dictionary = {}
	for result: Dictionary in world_node.get_world_3d().direct_space_state.intersect_shape(params, 64):
		var hb := result["collider"] as HurtBox
		if hb == null:
			continue
		var key := hb.entity_id()
		var current := best.get(key) as HurtBox
		if current == null or (current.is_weak_spot and not hb.is_weak_spot):
			best[key] = hb
	var hits := 0
	for hb: HurtBox in best.values():
		var info := make_info.call() as DamageInfo
		if hb.receive(info):
			hits += 1
	DebugSettings.flash_sphere(center, radius, Color(1, 0.2, 0.1), 0.35)
	NoiseEvent.emit(center, radius * NOISE_PER_RADIUS + NOISE_BASE, world_node)
	return hits
