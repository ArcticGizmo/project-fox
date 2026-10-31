class_name Bulwark
extends StaticBody3D
## A deployed hermit-crab shell wall. It is solid level geometry, so it
## blocks movement and shots (a charging bull stuns itself on it), and it
## projects a tall REFLECTOR field that bounces enemy lobs back at their
## thrower for reflect_damage.

const HEIGHT := 2.0
const THICKNESS := 0.6
## The reflect field reaches well above the wall to catch arcing lobs.
const FIELD_HEIGHT := 9.0
const SHELL_COLOR := Color(0.85, 0.45, 0.35)

var weapon: Weapon = null
var width: float = 3.0
var lifetime: float = 8.0
var reflect_damage: float = 25.0

var _age: float = 0.0
var _expiring: bool = false
var _mesh: MeshInstance3D


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	_mesh = MeshInstance3D.new()
	var mesh := _mesh
	var box := BoxMesh.new()
	box.size = Vector3(width, HEIGHT, THICKNESS)
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SHELL_COLOR
	mesh.material_override = mat
	mesh.position.y = HEIGHT * 0.5
	add_child(mesh)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	cs.shape = shape
	cs.position.y = HEIGHT * 0.5
	add_child(cs)

	var field := Area3D.new()
	field.name = "ReflectField"
	field.collision_layer = Layers.REFLECTOR
	field.collision_mask = 0
	field.monitoring = false
	field.monitorable = true
	var fcs := CollisionShape3D.new()
	var fshape := BoxShape3D.new()
	fshape.size = Vector3(width + 0.6, FIELD_HEIGHT, 1.6)
	fcs.shape = fshape
	fcs.position.y = FIELD_HEIGHT * 0.5
	field.add_child(fcs)
	add_child(field)

	# Animate only the mesh: scaling a physics body non-uniformly upsets the solver.
	_mesh.scale = Vector3(1, 0.05, 1)
	create_tween().tween_property(_mesh, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		expire()


func expire() -> void:
	if _expiring:
		return
	_expiring = true
	collision_layer = 0
	var tw := create_tween()
	tw.tween_property(_mesh, "scale", Vector3(1, 0.05, 1), 0.2)
	tw.tween_callback(queue_free)
