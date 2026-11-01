@tool
class_name Prop
extends Node3D
## Set dressing (docs/art-pipeline.md, "Dressing" layer): a model from assets/props/ (or a
## stand-in shape until the model exists), optionally with one simple collision box sized
## to the model. Props live under a level's `Level/Dressing` and never carry gameplay;
## `test_props` checks that colliding props stay out of the critical path.

enum Collision { NONE, BOX }
## Stand-in shapes for placing props before their models exist.
enum Placeholder { CRATE, BARREL, LANTERN, PLANTER }

const PLACEHOLDER_COLORS := {
	Placeholder.CRATE: Color(0.55, 0.38, 0.22),
	Placeholder.BARREL: Color(0.45, 0.3, 0.2),
	Placeholder.LANTERN: Color(0.72, 0.56, 0.25),
	Placeholder.PLANTER: Color(0.42, 0.55, 0.28),
}

## The model (a GLB or scene, origin at its base, facing -Z). Empty: draw the placeholder.
@export var model: PackedScene:
	set(value):
		model = value
		_rebuild()
@export var placeholder: Placeholder = Placeholder.CRATE:
	set(value):
		placeholder = value
		_rebuild()
@export var collision: Collision = Collision.NONE:
	set(value):
		collision = value
		_rebuild()
## Uniform scale so the model is this tall (metres); 0 keeps its authored size.
@export var fit_height: float = 0.0:
	set(value):
		fit_height = value
		_rebuild()

var _visual: Node3D
var _body: StaticBody3D


func _ready() -> void:
	add_to_group(&"dressing")
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _visual != null:
		_visual.free()
	if _body != null:
		_body.free()
		_body = null
	_visual = model.instantiate() as Node3D if model != null else _placeholder_mesh()
	_visual.name = "Visual"
	add_child(_visual)
	var bounds := local_bounds()
	if fit_height > 0.0 and bounds.size.y > 0.001:
		_visual.scale = Vector3.ONE * (fit_height / bounds.size.y)
		bounds = local_bounds()
	if collision == Collision.BOX:
		_body = StaticBody3D.new()
		_body.name = "Collision"
		_body.collision_layer = Layers.WORLD
		_body.collision_mask = 0
		var shape := BoxShape3D.new()
		shape.size = bounds.size
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = bounds.get_center()
		_body.add_child(cs)
		add_child(_body)


## The visual's bounding box in this node's space (every mesh under it).
func local_bounds() -> AABB:
	var out := AABB()
	var first := true
	if _visual == null:
		return out
	var inv := global_transform.affine_inverse() if is_inside_tree() else Transform3D.IDENTITY
	for mi: MeshInstance3D in _meshes(_visual):
		var xf := inv * mi.global_transform if is_inside_tree() else mi.transform
		var box := xf * mi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


## World-space bounds, for layout checks.
func world_bounds() -> AABB:
	return global_transform * local_bounds()


func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D:
		out.append(n as MeshInstance3D)
	for c: Node in n.get_children():
		out.append_array(_meshes(c))
	return out


func _placeholder_mesh() -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PLACEHOLDER_COLORS[placeholder]
	mat.roughness = 0.8
	match placeholder:
		Placeholder.CRATE:
			_part(root, _box(Vector3(0.9, 0.9, 0.9)), Vector3(0, 0.45, 0), mat)
		Placeholder.BARREL:
			_part(root, _cylinder(0.38, 0.33, 1.0), Vector3(0, 0.5, 0), mat)
		Placeholder.LANTERN:
			_part(root, _cylinder(0.06, 0.08, 2.4), Vector3(0, 1.2, 0), mat)
			var glow := StandardMaterial3D.new()
			glow.albedo_color = Color(1.0, 0.82, 0.5)
			glow.emission_enabled = true
			glow.emission = Color(1.0, 0.75, 0.4) * 2.0
			_part(root, _box(Vector3(0.3, 0.38, 0.3)), Vector3(0, 2.55, 0), glow)
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.8, 0.55)
			light.light_energy = 1.2
			light.omni_range = 6.0
			light.position = Vector3(0, 2.55, 0)
			root.add_child(light)
		Placeholder.PLANTER:
			_part(root, _box(Vector3(1.2, 0.5, 0.6)), Vector3(0, 0.25, 0), mat)
			var leaves := StandardMaterial3D.new()
			leaves.albedo_color = Color(0.36, 0.52, 0.24)
			_part(root, _sphere(0.45), Vector3(-0.28, 0.75, 0), leaves)
			_part(root, _sphere(0.38), Vector3(0.3, 0.7, 0), leaves)
	return root


func _part(root: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	root.add_child(mi)


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	return m


func _sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	return m
