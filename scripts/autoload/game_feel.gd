extends Node
## Global "juice": hit-stop, camera shake requests, damage numbers, impact puffs.
## Tests switch the timing-sensitive parts off (hit_stop_enabled = false).

signal shake_requested(strength: float)

var hit_stop_enabled: bool = true
var damage_numbers_enabled: bool = true

var _hit_stop_end_ms: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if _hit_stop_end_ms > 0 and Time.get_ticks_msec() >= _hit_stop_end_ms:
		_hit_stop_end_ms = 0
		Engine.time_scale = 1.0


## Briefly slows time so heavy hits "land". Duration is in real seconds.
func hit_stop(duration: float, time_scale: float = 0.05) -> void:
	if not hit_stop_enabled or duration <= 0.0:
		return
	Engine.time_scale = time_scale
	_hit_stop_end_ms = maxi(_hit_stop_end_ms, Time.get_ticks_msec() + int(duration * 1000.0))


func shake(strength: float) -> void:
	shake_requested.emit(strength)


func damage_number(world_pos: Vector3, amount: float, critical: bool = false) -> void:
	if not damage_numbers_enabled:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var label := Label3D.new()
	label.text = str(roundi(amount)) + ("!" if critical else "")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 56 if critical else 36
	label.outline_size = 10
	label.pixel_size = 0.008
	label.modulate = Color(1.0, 0.8, 0.15) if critical else Color.WHITE
	label.position = world_pos + Vector3(randf_range(-0.3, 0.3), 0.2, randf_range(-0.3, 0.3))
	scene.add_child(label)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y + 1.2, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.25)
	tw.chain().tween_callback(label.queue_free)


## Expanding, fading sphere. Cheap stand-in for particles.
func impact(world_pos: Vector3, color: Color, size: float = 0.6, duration: float = 0.18) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = world_pos
	mi.scale = Vector3.ONE * size * 0.3
	scene.add_child(mi)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size, duration).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(mi.queue_free)
