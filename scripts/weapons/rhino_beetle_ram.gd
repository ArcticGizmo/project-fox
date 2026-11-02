extends Weapon
## Rhino Beetle Ram: hold to charge, release to fire a beetle-shell slug
## (WeaponData.charge_time, Weapon.charge). Damage scales from MIN_POWER at the
## minimum charge to full at a full charge, speed and size with it. A full charge
## upends what it hits (Enemy.upend: a hop and a stagger; a pangolin flips onto
## its back) and pierces.
## stats: damage / projectile_speed / knockback = full-charge values,
## duration = upend time, pierce = full-charge pierce, max_range.
## Signature (max level): a full charge also upends every enemy within
## stats.area_radius of each hit.

const MIN_POWER := 0.35
const SLUG_SIZE := Vector3(0.35, 0.3, 0.5)


func _fire(aim: AimInfo) -> void:
	var s := stats()
	var full := charge >= 1.0
	var p := Projectile.new()
	p.direction = aim.direction
	p.speed = s.projectile_speed * lerpf(0.6, 1.0, charge)
	p.damage = s.damage * lerpf(MIN_POWER, 1.0, charge)
	p.lifetime = s.max_range / p.speed
	p.radius = 0.45 if full else 0.3
	p.pierce_left = s.pierce if full else 0
	p.hit_mask = hit_mask
	p.weapon = self
	p.color = data.color.lightened(0.35) if full else data.color
	p.size = SLUG_SIZE * lerpf(0.7, 1.3, charge)
	if full:
		p.on_hit = func(hb: HurtBox) -> void: _upend_hit(hb, s)
	spawn_parent().add_child(p)
	p.global_position = aim.origin
	GameFeel.shake(0.08 + 0.3 * charge)


func _upend_hit(hb: HurtBox, s: WeaponLevelStats) -> void:
	var e := Enemy.from_hurt_box(hb)
	if e != null:
		e.upend(s.duration)
	if not s.signature:
		return
	var at := hb.center()
	for other: Enemy in Enemy.in_radius(get_tree(), at, s.area_radius):
		if other != e:
			other.upend(s.duration)
	GameFeel.impact(at, data.color, s.area_radius * 2.0, 0.25)
	Sfx.play(&"impact_heavy", at)
	DebugSettings.flash_sphere(at, s.area_radius, data.color, 0.3)
