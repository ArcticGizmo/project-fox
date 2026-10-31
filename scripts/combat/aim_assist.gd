class_name AimAssist
extends RefCounted
## Picks the best target near an aim ray. Smaller angle wins; distance adds a
## mild penalty so a close enemy slightly off-centre beats a far one dead-centre.

## Degrees of angle penalty per metre of distance.
const DISTANCE_WEIGHT := 0.2


static func pick_target(origin: Vector3, direction: Vector3, candidates: Array[Node3D], max_angle_deg: float, max_range: float, space: PhysicsDirectSpaceState3D = null, los_from: Vector3 = Vector3.INF) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	var dir := direction.normalized()
	for c: Node3D in candidates:
		if not is_instance_valid(c):
			continue
		var point := get_aim_point(c)
		var to := point - origin
		var dist := to.length()
		if dist < 0.01 or dist > max_range:
			continue
		var angle := rad_to_deg(dir.angle_to(to / dist))
		if angle > max_angle_deg:
			continue
		var score := angle + dist * DISTANCE_WEIGHT
		if score >= best_score:
			continue
		if space != null and not has_line_of_sight(space, origin if los_from == Vector3.INF else los_from, point):
			continue
		best = c
		best_score = score
	return best


static func get_aim_point(n: Node3D) -> Vector3:
	if n.has_method(&"get_aim_point"):
		return n.call(&"get_aim_point")
	return n.global_position


static func has_line_of_sight(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	return space.intersect_ray(q).is_empty()


static func nodes_in_group(tree: SceneTree, group: StringName) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n: Node in tree.get_nodes_in_group(group):
		var n3 := n as Node3D
		if n3 != null:
			out.append(n3)
	return out
