extends Weapon
## Hermit Bulwark: raise a shell wall facing your aim. Blocks movement and
## shots, and reflects enemy lobs back at the thrower for stats.damage.
## stats: area_radius = wall width, duration = lifetime,
## projectile_count = walls out at once (the oldest retracts).

const DEPLOY_DISTANCE := 3.0

var walls: Array[Bulwark] = []


func _fire(aim: AimInfo) -> void:
	var s := stats()
	walls.assign(walls.filter(func(b: Variant) -> bool: return is_instance_valid(b) and not (b as Node).is_queued_for_deletion()))
	while walls.size() >= maxi(1, s.projectile_count):
		walls.pop_front().expire()
	var wall := Bulwark.new()
	wall.weapon = self
	wall.width = s.area_radius
	wall.lifetime = s.duration
	wall.reflect_damage = s.damage
	spawn_parent().add_child(wall)
	wall.global_position = deploy_point(aim, DEPLOY_DISTANCE)
	wall.rotation.y = Player.yaw_of(aim.direction)
	walls.append(wall)
