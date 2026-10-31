extends Weapon
## Galvanic Eel: a short-range bolt that hits the aim target, then jumps to
## the nearest un-hit enemy, losing a little damage per jump.
## stats: damage = first hit, pierce = number of extra jumps,
## area_radius = max jump distance, max_range = first-hit range.

const FALLOFF := 0.85
const JAGGED_SEGMENTS := 4
const JAG := 0.35

## Enemies hit by the last shot, in chain order (for tests and debugging).
var last_chain: Array[Node3D] = []


func _fire(aim: AimInfo) -> void:
	var s := stats()
	last_chain.clear()
	var first := _first_target(aim, s.max_range)
	if first == null:
		_bolt(aim.origin, aim.origin + aim.direction * s.max_range)
		return
	var from := aim.origin
	var current := first
	var dmg := s.damage
	for _i: int in s.pierce + 1:
		var point := AimAssist.get_aim_point(current)
		_bolt(from, point)
		_zap(current, dmg, from)
		last_chain.append(current)
		from = point
		current = _nearest_unhit(point, s.area_radius)
		if current == null:
			break
		dmg *= FALLOFF
	GameFeel.shake(0.06)


func _first_target(aim: AimInfo, max_range: float) -> Node3D:
	if aim.target != null and is_instance_valid(aim.target) and aim.target is Enemy:
		if aim.origin.distance_to(AimAssist.get_aim_point(aim.target)) <= max_range:
			return aim.target
	var q := PhysicsRayQueryParameters3D.create(aim.origin, aim.origin + aim.direction * max_range, hit_mask)
	q.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return null
	var hb := hit["collider"] as HurtBox
	if hb == null or hb.health == null:
		return null
	return hb.health.get_parent() as Node3D


func _nearest_unhit(from: Vector3, radius: float) -> Node3D:
	var best: Node3D = null
	var best_dist := radius
	var space := get_world_3d().direct_space_state
	for n: Node3D in AimAssist.nodes_in_group(get_tree(), &"enemies"):
		if n in last_chain:
			continue
		var p := AimAssist.get_aim_point(n)
		var d := from.distance_to(p)
		if d < best_dist and AimAssist.has_line_of_sight(space, from, p):
			best = n
			best_dist = d
	return best


func _zap(target: Node3D, amount: float, from: Vector3) -> void:
	var hb := target.get(&"hurt_box") as HurtBox
	if hb != null:
		hb.receive(make_damage(amount, from))
	GameFeel.impact(AimAssist.get_aim_point(target), data.color, 0.7, 0.12)


## Jagged lightning between two points.
func _bolt(a: Vector3, b: Vector3) -> void:
	var points: Array[Vector3] = [a]
	var dir := b - a
	var perp := dir.cross(Vector3.UP)
	perp = perp.normalized() if perp.length_squared() > 0.0001 else Vector3.RIGHT
	for i: int in range(1, JAGGED_SEGMENTS):
		var t := float(i) / JAGGED_SEGMENTS
		var offset := perp.rotated(dir.normalized(), randf() * TAU) * randf_range(-JAG, JAG)
		points.append(a + dir * t + offset)
	points.append(b)
	for i: int in points.size() - 1:
		Tracer.spawn(spawn_parent(), points[i], points[i + 1], data.color, 0.05, 0.1)
