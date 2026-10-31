extends Weapon
## Tortoise Sentry: deploy a turret on the ground in front of the fox.
## stats: projectile_count = max sentries alive (the oldest retires),
## duration = sentry lifetime, sub_interval = sentry fire interval,
## damage / projectile_speed / homing_deg_per_sec / max_range = its shots.

const DEPLOY_DISTANCE := 2.5

var sentries: Array[Sentry] = []


func _fire(aim: AimInfo) -> void:
	var s := stats()
	sentries.assign(sentries.filter(func(n: Variant) -> bool: return is_instance_valid(n) and not (n as Node).is_queued_for_deletion()))
	while sentries.size() >= maxi(1, s.projectile_count):
		sentries.pop_front().expire()
	var sentry := Sentry.new()
	sentry.weapon = self
	sentry.lifetime = s.duration
	spawn_parent().add_child(sentry)
	sentry.global_position = deploy_point(aim, DEPLOY_DISTANCE)
	sentries.append(sentry)
