class_name Tracer
extends MeshInstance3D
## Brief glowing beam for hitscan shots.


static func spawn(parent: Node, from: Vector3, to: Vector3, color: Color, width: float = 0.06, duration: float = 0.12) -> void:
	var length := from.distance_to(to)
	if length < 0.01:
		return
	var t := Tracer.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, width, length)
	t.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	t.material_override = mat
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t.top_level = true
	parent.add_child(t)
	var mid := (from + to) * 0.5
	var up := Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT
	t.global_transform = Transform3D(Basis.IDENTITY, mid).looking_at(to, up)
	var tw := t.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, duration)
	tw.tween_callback(t.queue_free)
