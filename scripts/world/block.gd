@tool
class_name Block
extends StaticBody3D
## A box of level geometry with matching collision. Works in the editor (@tool) so you
## can grey-box levels by dragging these around. `surface` picks how it is drawn: GREYBOX
## is the flat `color`; the other roles take a textured SurfaceStyle from the level's
## LevelTheme (docs/art-pipeline.md). The role never changes collision.

enum Surface { GREYBOX, GROUND, PATH, PLATFORM, WALL, METAL }

@export var size: Vector3 = Vector3(4, 1, 4):
	set(value):
		size = value
		_rebuild()
@export var color: Color = Color(0.5, 0.5, 0.5):
	set(value):
		color = value
		_rebuild()
@export var surface: Surface = Surface.GREYBOX:
	set(value):
		surface = value
		_rebuild()

var _mesh: MeshInstance3D
var _shape: CollisionShape3D


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	_rebuild()


func _rebuild() -> void:
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		add_child(_mesh)
		_shape = CollisionShape3D.new()
		add_child(_shape)
	var box := BoxMesh.new()
	box.size = size
	_mesh.mesh = box
	var style := surface_style()
	if style != null:
		_mesh.material_override = style.material()
		_mesh.set_instance_shader_parameter(&"half_size", size * 0.5)
	else:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _display_color()
		mat.roughness = 0.9
		_mesh.material_override = mat
	var shape := BoxShape3D.new()
	shape.size = size
	_shape.shape = shape
	_decorate()


## The textured style for this Block's role from the nearest level's theme (or the
## default theme), or null to draw the flat colour.
func surface_style() -> SurfaceStyle:
	if surface == Surface.GREYBOX:
		return null
	var theme := LevelTheme.default_theme()
	if is_inside_tree():
		var n := get_parent()
		while n != null:
			var t: Variant = n.get(&"level_theme")
			if t is LevelTheme:
				theme = t as LevelTheme
				break
			n = n.get_parent()
	return theme.style_for(surface) if theme != null else null


## Colour actually drawn (subclasses such as GadgetGate override it).
func _display_color() -> Color:
	return color


## Hook for subclasses to add marker meshes after a rebuild.
func _decorate() -> void:
	pass
