extends Weapon
## Woodpecker Repeater: the simple blaster. Rapid, straight rivets fired
## exactly at the reticle (WeaponData.uses_aim_assist = false, so no lock-on).
## Spread "blooms" while the trigger is held; stats.spread_deg is the maximum.
## stats.projectile_count > 1 fires from alternating twin barrels.

const BLOOM_PER_SHOT := 0.15
const BLOOM_RECOVERY_PER_SEC := 3.0
const BARREL_OFFSET := 0.12

## 0 = perfectly accurate, 1 = full spread_deg.
var bloom: float = 0.0


func _physics_process(delta: float) -> void:
	super(delta)
	if not _trigger_held:
		bloom = maxf(0.0, bloom - BLOOM_RECOVERY_PER_SEC * delta)


func _fire(aim: AimInfo) -> void:
	var s := stats()
	var count := maxi(1, s.projectile_count)
	var right := aim.direction.cross(Vector3.UP)
	right = right.normalized() if right.length_squared() > 0.0001 else Vector3.RIGHT
	for i: int in count:
		var p := Projectile.new()
		p.direction = spread_direction(aim.direction, deg_to_rad(s.spread_deg) * bloom)
		p.speed = s.projectile_speed
		p.damage = s.damage
		p.lifetime = s.max_range / s.projectile_speed
		p.radius = 0.12
		p.pierce_left = s.pierce
		p.hit_mask = hit_mask
		p.weapon = self
		p.color = data.color
		p.size = Vector3(0.07, 0.07, 0.5)
		spawn_parent().add_child(p)
		var side := 0.0 if count == 1 else (float(i) / float(count - 1) - 0.5) * 2.0
		p.global_position = aim.origin + right * side * BARREL_OFFSET
	bloom = minf(1.0, bloom + BLOOM_PER_SHOT)
	GameFeel.shake(0.03)


## Random direction within `max_angle` radians of `dir`.
static func spread_direction(dir: Vector3, max_angle: float) -> Vector3:
	if max_angle <= 0.0:
		return dir.normalized()
	var perp := dir.cross(Vector3.UP)
	if perp.length_squared() < 0.0001:
		perp = Vector3.RIGHT
	perp = perp.normalized().rotated(dir.normalized(), randf() * TAU)
	return dir.normalized().rotated(perp, randf() * max_angle)
