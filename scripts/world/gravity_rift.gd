@tool
class_name GravityRift
extends Area3D
## STUB (plan Task 3): a magical zone where gravity points along the zone's local
## -Y. The volume, visual and `gravity_direction()` exist so levels can place
## rifts, but nothing reacts yet: Player movement, floor checks, jumping and the
## camera all assume world-up (velocity.y, is_on_floor, CameraRig pitch), so real
## support means moving the player onto an `up_direction` basis. See the plan doc.

@export var size: Vector3 = Vector3(6, 6, 6):
	set(value):
		size = value
		_rebuild()

var _mesh: MeshInstance3D
var _shape: CollisionShape3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER | Layers.ENEMY
	monitorable = false
	_rebuild()


## World-space direction gravity pulls inside this rift.
func gravity_direction() -> Vector3:
	return -global_basis.y.normalized()


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
	mat.albedo_color = Color(0.55, 0.3, 0.9, 0.18)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.2, 0.8) * 0.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh.material_override = mat
	var shape := BoxShape3D.new()
	shape.size = size
	_shape.shape = shape
