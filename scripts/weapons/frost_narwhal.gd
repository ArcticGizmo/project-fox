extends Weapon
## Frost Narwhal: fast icy lances that chill. Enough chill freezes an enemy
## (see Enemy): frozen enemies stop dead and take extra damage from every
## weapon, so this pairs with heavy hitters like the rifle and the staff.
## stats: status_power = chill added per hit (1.0 = instant freeze),
## duration = freeze time, pierce = extra enemies per lance.
## Signature (max level): a lance that kills a frozen enemy shatters it,
## adding 2 x status_power chill to every enemy within stats.area_radius.

const SHATTER_CHILL_FACTOR := 2.0


func _fire(aim: AimInfo) -> void:
	var s := stats()
	var p := Projectile.new()
	p.direction = aim.direction
	p.speed = s.projectile_speed
	p.damage = s.damage
	p.lifetime = s.max_range / s.projectile_speed
	p.radius = 0.2
	p.pierce_left = s.pierce
	p.hit_mask = hit_mask
	p.weapon = self
	p.color = data.color
	p.size = Vector3(0.09, 0.09, 0.8)
	p.on_hit = func(hb: HurtBox) -> void:
		var e := Enemy.from_hurt_box(hb)
		if e == null:
			return
		if e.health.is_dead:
			if s.signature and e.is_frozen():
				shatter(e, s)
		else:
			e.add_chill(s.status_power, s.duration)
	spawn_parent().add_child(p)
	p.global_position = aim.origin


## Bursts a frozen corpse, chilling its neighbours. Returns how many it chilled.
func shatter(victim: Enemy, s: WeaponLevelStats) -> int:
	var at := victim.get_aim_point()
	var chilled := 0
	for e: Enemy in Enemy.in_radius(get_tree(), at, s.area_radius):
		if e == victim or e.health.is_dead:
			continue
		e.add_chill(s.status_power * SHATTER_CHILL_FACTOR, s.duration)
		chilled += 1
	GameFeel.impact(at, Enemy.FREEZE_COLOR, s.area_radius * 2.0, 0.3)
	Sfx.play(&"shot_frost", at, 4.0)
	DebugSettings.flash_sphere(at, s.area_radius, Enemy.FREEZE_COLOR, 0.3)
	return chilled
