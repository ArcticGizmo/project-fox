class_name DebugOutline
extends MeshInstance3D
## Wireframe of every CollisionShape3D directly under an Area3D. Colour comes
## from the area's get_debug_color(); visibility follows DebugSettings.show_boxes.
## Call rebuild() (via HitBox/HurtBox.refresh_outline) after changing shapes.
##
## ConvexPolygonShape3D is drawn as a cone: points[0] is the apex and the
## remaining points form the base ring.

const SEGMENTS := 24

var _area: Area3D
var _material: StandardMaterial3D


static func attach(area: Area3D) -> DebugOutline:
	var outline := DebugOutline.new()
	outline.name = "DebugOutline"
	outline._area = area
	area.add_child(outline)
	return outline


static func make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 10
	mat.albedo_color = color
	return mat


static func lines_to_mesh(lines: PackedVector3Array) -> ArrayMesh:
	if lines.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = lines
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	return mesh


static func append_shape_lines(out: PackedVector3Array, shape: Shape3D) -> void:
	if shape is BoxShape3D:
		var h := (shape as BoxShape3D).size * 0.5
		var c: Array[Vector3] = []
		for i: int in 8:
			c.append(Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
		for e: Vector2i in [Vector2i(0, 1), Vector2i(2, 3), Vector2i(4, 5), Vector2i(6, 7),
				Vector2i(0, 2), Vector2i(1, 3), Vector2i(4, 6), Vector2i(5, 7),
				Vector2i(0, 4), Vector2i(1, 5), Vector2i(2, 6), Vector2i(3, 7)]:
			out.append(c[e.x])
			out.append(c[e.y])
	elif shape is SphereShape3D:
		var r := (shape as SphereShape3D).radius
		_circle(out, Vector3.ZERO, Vector3.RIGHT, Vector3.BACK, r)
		_circle(out, Vector3.ZERO, Vector3.RIGHT, Vector3.UP, r)
		_circle(out, Vector3.ZERO, Vector3.BACK, Vector3.UP, r)
	elif shape is CapsuleShape3D:
		var cap := shape as CapsuleShape3D
		var r := cap.radius
		var half := maxf(cap.height * 0.5 - r, 0.0)
		var top := Vector3(0, half, 0)
		_circle(out, top, Vector3.RIGHT, Vector3.BACK, r)
		_circle(out, -top, Vector3.RIGHT, Vector3.BACK, r)
		for d: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
			out.append(top + d * r)
			out.append(-top + d * r)
		_circle(out, top, Vector3.RIGHT, Vector3.UP, r, 0.0, PI)
		_circle(out, -top, Vector3.RIGHT, Vector3.UP, r, PI, TAU)
		_circle(out, top, Vector3.BACK, Vector3.UP, r, 0.0, PI)
		_circle(out, -top, Vector3.BACK, Vector3.UP, r, PI, TAU)
	elif shape is CylinderShape3D:
		var cyl := shape as CylinderShape3D
		var top := Vector3(0, cyl.height * 0.5, 0)
		_circle(out, top, Vector3.RIGHT, Vector3.BACK, cyl.radius)
		_circle(out, -top, Vector3.RIGHT, Vector3.BACK, cyl.radius)
		for d: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
			out.append(top + d * cyl.radius)
			out.append(-top + d * cyl.radius)
	elif shape is ConvexPolygonShape3D:
		var pts := (shape as ConvexPolygonShape3D).points
		if pts.size() < 3:
			return
		var n := pts.size() - 1
		for i: int in n:
			out.append(pts[0])
			out.append(pts[i + 1])
			out.append(pts[i + 1])
			out.append(pts[(i + 1) % n + 1])


static func _circle(out: PackedVector3Array, center: Vector3, a: Vector3, b: Vector3, r: float, from: float = 0.0, to: float = TAU) -> void:
	for i: int in SEGMENTS:
		var t0 := from + (to - from) * float(i) / SEGMENTS
		var t1 := from + (to - from) * float(i + 1) / SEGMENTS
		out.append(center + (a * cos(t0) + b * sin(t0)) * r)
		out.append(center + (a * cos(t1) + b * sin(t1)) * r)


func _ready() -> void:
	_material = make_material(Color.WHITE)
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rebuild()
	visible = DebugSettings.show_boxes
	DebugSettings.show_boxes_changed.connect(_on_show_boxes_changed)


func _process(_delta: float) -> void:
	if DebugSettings.show_boxes and _area.has_method(&"outline_visible"):
		visible = bool(_area.call(&"outline_visible"))
	if visible and _area.has_method(&"get_debug_color"):
		_material.albedo_color = _area.call(&"get_debug_color")


func rebuild() -> void:
	var lines := PackedVector3Array()
	for child: Node in _area.get_children():
		var cs := child as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		var local := PackedVector3Array()
		append_shape_lines(local, cs.shape)
		for p: Vector3 in local:
			lines.append(cs.transform * p)
	mesh = lines_to_mesh(lines)


func line_count() -> int:
	if mesh == null:
		return 0
	return (mesh as ArrayMesh).surface_get_array_len(0) / 2


func _on_show_boxes_changed(enabled: bool) -> void:
	visible = enabled
