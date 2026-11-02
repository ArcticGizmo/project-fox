extends Weapon
## Clockwork Swallow: darts that fly a curve around the aim target and strike it
## from behind (see SwallowDart), slipping past frontal armour. Successive darts
## alternate curving left and right. With no target they curve onto the aim point.
## stats: damage, projectile_speed, projectile_count = darts per shot,
## area_radius = curve width, max_range = furthest aim point.
## Signature (max level): hits in an enemy's back crit for stats.crit_multiplier.

## Darts fired by the last shot (tests).
var last_darts: Array[SwallowDart] = []
## Hits that landed in an enemy's back (tests, tuning).
var back_hits: int = 0
var _next_side: float = 1.0


func _fire(aim: AimInfo) -> void:
	var s := stats()
	last_darts.clear()
	var end := aim.point
	if aim.origin.distance_to(end) > s.max_range:
		end = aim.origin + (end - aim.origin).normalized() * s.max_range
	for i: int in maxi(1, s.projectile_count):
		var d := SwallowDart.new()
		d.weapon = self
		d.target = aim.target
		d.end_point = end
		d.side = _next_side
		_next_side = -_next_side
		d.width = s.area_radius
		d.speed = s.projectile_speed
		d.damage = s.damage
		d.back_multiplier = s.crit_multiplier if s.signature else 1.0
		d.color = data.color
		# top_level: the curve is in world space whatever the spawn parent is.
		d.top_level = true
		d.position = aim.origin
		spawn_parent().add_child(d)
		last_darts.append(d)
		d.struck.connect(_on_dart_struck)


func _on_dart_struck(_enemy: Enemy, from_behind: bool) -> void:
	if from_behind:
		back_hits += 1
