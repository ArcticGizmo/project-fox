extends Weapon
## Echo Bat Horn: an instant sonic cone. Everything inside is damaged,
## knocked back, staggered (attacks interrupted, e.g. a bull's charge) and
## exposed (takes extra damage for a while).
## stats: max_range = cone length, area_radius = cone end radius,
## duration = stagger time, status_power = exposed time.

const CONE_COLOR := Color(0.55, 0.65, 1.0, 0.35)

## Enemies hit by the last blast (for tests and debugging).
var last_hits: Array[Enemy] = []


func _fire(aim: AimInfo) -> void:
	var s := stats()
	last_hits.clear()
	var half_angle := atan2(s.area_radius, s.max_range)
	var dir := aim.direction.normalized()
	var space := get_world_3d().direct_space_state
	for n: Node in get_tree().get_nodes_in_group(&"enemies"):
		var e := n as Enemy
		if e == null or e.health.is_dead:
			continue
		var to := e.get_aim_point() - aim.origin
		var dist := to.length()
		# Measure to the body's edge so big enemies are caught by the cone's tip.
		var body_radius := maxf(e.extents().x, e.extents().z) * 0.5
		if dist - body_radius > s.max_range or (dist > 0.01 and dir.angle_to(to / dist) > half_angle + atan2(body_radius, dist)):
			continue
		if not AimAssist.has_line_of_sight(space, aim.origin, e.get_aim_point()):
			continue
		e.hurt_box.receive(make_damage(s.damage, aim.origin))
		e.stagger(s.duration)
		e.expose(s.status_power)
		last_hits.append(e)
	_flash_cone(aim.origin, dir, s.max_range, s.area_radius)
	GameFeel.shake(0.2)


func _flash_cone(origin: Vector3, dir: Vector3, length: float, radius: float) -> void:
	var cone := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = 0.1
	mesh.height = length
	cone.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = CONE_COLOR
	cone.material_override = mat
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spawn_parent().add_child(cone)
	# Cylinder axis is +Y; point it along dir with the narrow end at the origin.
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	var cone_basis := Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, -PI * 0.5)
	cone.global_transform = Transform3D(cone_basis, origin + dir * length * 0.5)
	var tw := cone.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(cone.queue_free)
	DebugSettings.flash_line(origin, origin + dir * length, Color(0.5, 0.6, 1.0), 0.3)
