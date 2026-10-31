@tool
class_name Block
extends StaticBody3D
## A coloured box of level geometry with matching collision. Works in the
## editor (@tool) so you can grey-box levels by dragging these around.

@export var size: Vector3 = Vector3(4, 1, 4):
	set(value):
		size = value
		_rebuild()
@export var color: Color = Color(0.5, 0.5, 0.5):
	set(value):
		color = value
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
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	_mesh.material_override = mat
	var shape := BoxShape3D.new()
	shape.size = size
	_shape.shape = shape
