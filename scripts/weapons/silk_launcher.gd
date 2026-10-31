extends Weapon
## Spider Silk Launcher: a sticky glob that bursts into a web wherever it
## lands, rooting every enemy inside (they still turn and attack, but can't
## move). Crowd control that sets up the mortar, lash and slam.
## stats: area_radius = web radius, duration = root time, damage = glob hit.

const WEB_COLOR := Color(1, 1, 1, 0.35)


func _fire(aim: AimInfo) -> void:
	var s := stats()
	var p := Projectile.new()
	p.direction = aim.direction
	p.speed = s.projectile_speed
	p.damage = s.damage
	p.lifetime = s.max_range / s.projectile_speed
	p.radius = 0.3
	p.hit_mask = hit_mask
	p.weapon = self
	p.color = data.color
	p.size = Vector3(0.3, 0.3, 0.3)
	p.on_impact = func(at: Vector3) -> void: burst(at, s.area_radius, s.duration)
	spawn_parent().add_child(p)
	p.global_position = aim.origin


## Roots every enemy within `radius` of `at`. Returns how many were caught.
func burst(at: Vector3, radius: float, duration: float) -> int:
	var caught := 0
	for e: Enemy in Enemy.in_radius(get_tree(), at, radius):
		e.root(duration)
		caught += 1
	_spawn_web(at, radius, duration)
	DebugSettings.flash_sphere(at, radius, Color(1, 1, 1), 0.3)
	return caught


func _spawn_web(at: Vector3, radius: float, duration: float) -> void:
	var web := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.03
	web.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = WEB_COLOR
	web.material_override = mat
	web.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spawn_parent().add_child(web)
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 20.0, Layers.WORLD)
	var ground := get_world_3d().direct_space_state.intersect_ray(q)
	web.global_position = (at if ground.is_empty() else (ground["position"] as Vector3)) + Vector3.UP * 0.04
	var tw := web.create_tween()
	tw.tween_interval(maxf(0.0, duration - 0.4))
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tw.tween_callback(web.queue_free)
