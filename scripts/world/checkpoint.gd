@tool
class_name Checkpoint
extends Area3D
## A lamp post the player respawns at. Touching it sets Player.spawn_point (and
## spawn_yaw = this node's yaw, so face the post the way play continues) and lights
## the lamp. The most recently touched checkpoint wins; the others go dark.
## Touching one resets nothing; LevelRoot resets placed enemies on respawn.

signal activated(player: Player)

const DIM_COLOR := Color(0.25, 0.3, 0.38)
const LIT_COLOR := Color(1.0, 0.75, 0.3)
const POST_HEIGHT := 1.8

## Radius of the trigger volume around the post.
@export var radius: float = 1.5

var active: bool = false

var _lamp_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group(&"checkpoints")
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitorable = false
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 3.0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 1.5
	add_child(cs)
	_build_visual()
	_apply_look()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


## Where the player reappears (on the pad, just above the floor).
func spawn_position() -> Vector3:
	return global_position + Vector3(0, 0.1, 0)


func activate(player: Player) -> void:
	player.spawn_point = spawn_position()
	player.spawn_yaw = global_rotation.y
	if active:
		return
	for n: Node in get_tree().get_nodes_in_group(&"checkpoints"):
		if n != self and n is Checkpoint:
			(n as Checkpoint)._set_active(false)
	_set_active(true)
	GameFeel.impact(global_position + Vector3(0, POST_HEIGHT + 0.3, 0), LIT_COLOR, 1.2, 0.3)
	activated.emit(player)


func _on_body_entered(body: Node3D) -> void:
	var p := body as Player
	if p != null and not p.is_dead:
		activate(p)


func _set_active(on: bool) -> void:
	active = on
	_apply_look()


func _build_visual() -> void:
	var pad := CylinderMesh.new()
	pad.top_radius = radius * 0.8
	pad.bottom_radius = radius * 0.8
	pad.height = 0.08
	_ring_mat = _mat(DIM_COLOR)
	_add_mesh(pad, Vector3(0, 0.04, 0), _ring_mat)
	var post := CylinderMesh.new()
	post.top_radius = 0.08
	post.bottom_radius = 0.12
	post.height = POST_HEIGHT
	_add_mesh(post, Vector3(0, POST_HEIGHT * 0.5, 0), _mat(Color(0.35, 0.28, 0.2)))
	var lamp := SphereMesh.new()
	lamp.radius = 0.22
	lamp.height = 0.44
	_lamp_mat = _mat(DIM_COLOR)
	_add_mesh(lamp, Vector3(0, POST_HEIGHT + 0.15, 0), _lamp_mat)


func _apply_look() -> void:
	if _lamp_mat == null:
		return
	var c := LIT_COLOR if active else DIM_COLOR
	_lamp_mat.albedo_color = c
	_lamp_mat.emission_enabled = active
	_lamp_mat.emission = c * 2.0
	_ring_mat.albedo_color = c.darkened(0.3) if active else DIM_COLOR
	_ring_mat.emission_enabled = active
	_ring_mat.emission = c * 0.5


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	return m


func _add_mesh(mesh: Mesh, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
