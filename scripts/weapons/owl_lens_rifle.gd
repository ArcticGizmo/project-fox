extends Weapon
## Owl-Lens Rifle: slow, heavy hitscan. Weak-spot hits crit (stats.crit_multiplier);
## pierces extra enemies at higher levels.
## Signature (max level): weak-spot crits stagger the target for stats.duration.

const MAX_RAY_STEPS := 16


func _fire(aim: AimInfo) -> void:
	var s := stats()
	var space := get_world_3d().direct_space_state
	var from := aim.origin
	var end := from + aim.direction * s.max_range
	var beam_end := end
	var exclude: Array[RID] = []
	var hit_entities: Dictionary = {}
	var pierce_left := s.pierce
	for _i: int in MAX_RAY_STEPS:
		var q := PhysicsRayQueryParameters3D.create(from, end, hit_mask, exclude)
		q.collide_with_areas = true
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		var pos: Vector3 = hit["position"]
		var hb := hit["collider"] as HurtBox
		if hb == null:
			beam_end = pos
			break
		exclude.append(hb.get_rid())
		if hit_entities.has(hb.entity_id()):
			continue
		hit_entities[hb.entity_id()] = true
		var info := make_damage(s.damage, from)
		if hb.is_weak_spot:
			info.amount *= s.crit_multiplier
		if not hb.receive(info):
			continue
		GameFeel.impact(pos, data.color, 0.9)
		if s.signature and hb.is_weak_spot:
			var e := Enemy.from_hurt_box(hb)
			if e != null:
				e.stagger(s.duration)
		GameFeel.hit_stop(s.hit_stop)
		if pierce_left <= 0:
			beam_end = pos
			break
		pierce_left -= 1
	Tracer.spawn(spawn_parent(), from, beam_end, data.color)
	DebugSettings.flash_line(from, beam_end, Color(1, 0.2, 0.2))
	GameFeel.shake(0.15)
