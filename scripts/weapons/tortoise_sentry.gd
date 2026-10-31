extends Weapon
## Tortoise Sentry: deploy a turret on the ground in front of the fox.
## stats: projectile_count = max sentries alive (the oldest retires),
## duration = sentry lifetime, sub_interval = sentry fire interval,
## damage / projectile_speed / homing_deg_per_sec / max_range = its shots.

const DEPLOY_DISTANCE := 2.5

var sentries: Array[Sentry] = []


func _fire(aim: AimInfo) -> void:
	var s := stats()
	sentries.assign(sentries.filter(func(n: Sentry) -> bool: return is_instance_valid(n) and not n.is_queued_for_deletion()))
	while sentries.size() >= maxi(1, s.projectile_count):
		sentries.pop_front().expire()
	var sentry := Sentry.new()
	sentry.weapon = self
	sentry.lifetime = s.duration
	spawn_parent().add_child(sentry)
	sentry.global_position = _deploy_point(aim)
	sentries.append(sentry)


func _deploy_point(aim: AimInfo) -> Vector3:
	var base := wielder.global_position if wielder != null else aim.origin
	var flat := aim.direction
	flat.y = 0.0
	flat = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD
	var p := base + flat * DEPLOY_DISTANCE
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.0, p + Vector3.DOWN * 6.0, Layers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return p if hit.is_empty() else (hit["position"] as Vector3)
