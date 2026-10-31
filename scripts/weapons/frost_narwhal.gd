extends Weapon
## Frost Narwhal: fast icy lances that chill. Enough chill freezes an enemy
## (see Enemy): frozen enemies stop dead and take extra damage from every
## weapon, so this pairs with heavy hitters like the rifle and the staff.
## stats: status_power = chill added per hit (1.0 = instant freeze),
## duration = freeze time, pierce = extra enemies per lance.


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
		if e != null:
			e.add_chill(s.status_power, s.duration)
	spawn_parent().add_child(p)
	p.global_position = aim.origin
