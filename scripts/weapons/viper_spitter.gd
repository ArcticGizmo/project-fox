extends Weapon
## Viper Spitter: lobs venom that leaves a poison puddle (see VenomGlob).
## Area denial: enemies that walk through or stand in it stack poison.
## stats: damage = splash, area_radius = puddle radius, duration = puddle
## lifetime, status_power = poison stacks per 0.5s, max_range = throw range,
## upgrade_flag = contagious poison (spreads to neighbours on death).


func _fire(aim: AimInfo) -> void:
	var s := stats()
	var landing := aim.point
	var flat := landing - aim.origin
	flat.y = 0.0
	if flat.length() > s.max_range:
		landing = aim.origin + flat.normalized() * s.max_range + Vector3.UP * (landing.y - aim.origin.y)
	var glob := VenomGlob.new()
	glob.weapon = self
	glob.damage = s.damage
	glob.radius = s.area_radius
	glob.lifetime = s.duration
	glob.stacks_per_tick = maxi(1, roundi(s.status_power))
	glob.contagious = s.upgrade_flag
	glob.color = data.color
	glob.velocity = PufferMine.launch_velocity(aim.origin, landing, PufferMine.flight_time_for(aim.origin, landing))
	spawn_parent().add_child(glob)
	glob.global_position = aim.origin
