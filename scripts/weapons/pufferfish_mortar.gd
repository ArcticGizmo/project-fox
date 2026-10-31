extends Weapon
## Pufferfish Mortar: lobs pufferfish at the aim point. They explode on a
## direct hit or sit as proximity mines (see PufferMine).
## stats: damage, area_radius = blast radius, projectile_count = puffers per
## shot (spread sideways), duration = mine fuse, max_range = throw distance.

const VOLLEY_SPACING := 2.2


func _fire(aim: AimInfo) -> void:
	var s := stats()
	var target := aim.point
	var flat := target - aim.origin
	flat.y = 0.0
	if flat.length() > s.max_range:
		target = aim.origin + flat.normalized() * s.max_range + Vector3.UP * (target.y - aim.origin.y)
	var side := flat.cross(Vector3.UP)
	side = side.normalized() if side.length_squared() > 0.0001 else Vector3.RIGHT
	var count := maxi(1, s.projectile_count)
	for i: int in count:
		var offset := (float(i) - float(count - 1) * 0.5) * VOLLEY_SPACING
		var landing := target + side * offset
		var mine := PufferMine.new()
		mine.weapon = self
		mine.damage = s.damage
		mine.blast_radius = s.area_radius
		mine.knockback = s.knockback
		mine.fuse = s.duration
		mine.color = data.color
		mine.velocity = PufferMine.launch_velocity(aim.origin, landing, PufferMine.flight_time_for(aim.origin, landing))
		spawn_parent().add_child(mine)
		mine.global_position = aim.origin
	GameFeel.shake(0.08)
