extends Node
## Global debug toggles. Hitbox/hurtbox outlines and enemy state labels are
## off by default. Toggle with Back/Select on a controller or F1 on keyboard.
##
## Outline colours:
##   red       = active HitBox (deals damage right now)
##   dark red  = inactive HitBox
##   green     = HurtBox
##   orange    = weak-spot HurtBox (bonus damage)
##   cyan      = invulnerable HurtBox (dodge / hurt i-frames)

signal show_boxes_changed(enabled: bool)

var show_boxes: bool = false:
	set(value):
		if value == show_boxes:
			return
		show_boxes = value
		show_boxes_changed.emit(value)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle_boxes"):
		show_boxes = not show_boxes


## Short-lived sphere outline for instant area queries (explosions).
func flash_sphere(center: Vector3, radius: float, color: Color, duration: float = 0.3) -> void:
	if not show_boxes:
		return
	var lines := PackedVector3Array()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	DebugOutline.append_shape_lines(lines, sphere)
	_spawn_lines(lines, center, color, duration)


## Short-lived line for hitscan rays.
func flash_line(from: Vector3, to: Vector3, color: Color, duration: float = 0.3) -> void:
	if not show_boxes:
		return
	_spawn_lines(PackedVector3Array([Vector3.ZERO, to - from]), from, color, duration)


func _spawn_lines(lines: PackedVector3Array, origin: Vector3, color: Color, duration: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = DebugOutline.lines_to_mesh(lines)
	mi.material_override = DebugOutline.make_material(color)
	mi.top_level = true
	scene.add_child(mi)
	mi.global_position = origin
	get_tree().create_timer(duration).timeout.connect(mi.queue_free)
