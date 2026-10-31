extends Weapon
## Moth Lantern: plant a glowing decoy that draws every enemy within
## stats.area_radius away from you. It bursts for stats.damage when enemies
## break it (stats.deploy_health) or when stats.duration runs out.
## stats.projectile_count = max decoys out at once (the oldest bursts).

const DEPLOY_DISTANCE := 3.0

var decoys: Array[MothLanternDecoy] = []


func _fire(aim: AimInfo) -> void:
	var s := stats()
	decoys.assign(decoys.filter(func(d: MothLanternDecoy) -> bool: return is_instance_valid(d) and not d.is_queued_for_deletion()))
	while decoys.size() >= maxi(1, s.projectile_count):
		decoys.pop_front().burst()
	var decoy := MothLanternDecoy.new()
	decoy.weapon = self
	decoy.lure_radius = s.area_radius
	decoy.lifetime = s.duration
	decoy.blast_damage = s.damage
	decoy.max_health = s.deploy_health
	spawn_parent().add_child(decoy)
	decoy.global_position = deploy_point(aim, DEPLOY_DISTANCE)
	decoys.append(decoy)
