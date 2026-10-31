extends Weapon
## Clockwork Hornet Swarm: a fan of homing hornets that spread out, then curve
## into the aim-assist target (or the nearest enemy ahead).

const HOMING_DELAY := 0.08
const LIFT_DEG := 10.0


func _fire(aim: AimInfo) -> void:
	var s := stats()
	var count := maxi(1, s.projectile_count)
	var right := aim.direction.cross(Vector3.UP)
	right = right.normalized() if right.length_squared() > 0.0001 else Vector3.RIGHT
	for i: int in count:
		var t := 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		var dir := aim.direction.rotated(Vector3.UP, deg_to_rad(s.spread_deg) * t)
		dir = dir.rotated(right, deg_to_rad(randf_range(0.0, LIFT_DEG)))
		var p := Projectile.new()
		p.direction = dir.normalized()
		p.speed = s.projectile_speed * randf_range(0.92, 1.08)
		p.damage = s.damage
		p.lifetime = s.max_range / s.projectile_speed * 1.5
		p.radius = 0.3
		p.pierce_left = s.pierce
		p.homing_deg_per_sec = s.homing_deg_per_sec
		p.homing_delay = HOMING_DELAY
		p.homing_target = aim.target
		p.hit_mask = hit_mask
		p.weapon = self
		p.color = data.color
		p.size = Vector3(0.18, 0.12, 0.35)
		spawn_parent().add_child(p)
		p.global_position = aim.origin
	GameFeel.shake(0.05)
