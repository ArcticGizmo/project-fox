@tool
class_name ConduitTerminal
extends Node3D
## A dead copper post (Copper Conduit Gauntlet). Staff-hit it with a charged
## gauntlet: the charge is spent, the terminal powers up for good (its lamp and
## the floor cable light), emits `powered` and calls `power()` (or `open()`) on
## `target`, e.g. a conduit GadgetGate door. Without a charge, or without the
## gadget, a swing just clanks. Origin at floor level; the post is solid world
## geometry and the head carries a ConduitSocket the staff can strike.

signal powered
## Struck without a charge (or without the gadget): a dull clank.
signal clanked

const GROUP := &"conduit_terminals"
const COPPER := Color(0.78, 0.42, 0.24)
const DEAD_LAMP := Color(0.22, 0.26, 0.3)
const LIVE_LAMP := Color(0.55, 0.85, 1.0)
const POST_HEIGHT := 1.3
const HEAD_HEIGHT := 1.5

## Node with power() or open() that this terminal drives (a door, a lift).
@export var target: NodePath:
	set(value):
		target = value
		_rebuild()

var is_powered: bool = false
var socket: ConduitSocket

var _visual: Node3D
var _lamp_material: StandardMaterial3D
var _cable_material: StandardMaterial3D
var _head: MeshInstance3D
var _age: float = 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group(GROUP)
	_rebuild()
	if not Engine.is_editor_hint():
		socket = ConduitSocket.make(self, "ConduitSocket", Vector3(1.1, 1.6, 1.1), Vector3(0, 1.0, 0), self)


func _process(delta: float) -> void:
	_age += delta
	if is_powered and _lamp_material != null:
		_lamp_material.emission = LIVE_LAMP * (2.2 + 0.5 * sin(_age * 9.0))


## The node `target` points at, or null.
func target_node() -> Node:
	if target.is_empty() or not is_inside_tree():
		return null
	return get_node_or_null(target)


func conduit_struck(gauntlet: ConduitGauntlet, unlocked: bool) -> void:
	if is_powered:
		return
	var contact := global_position + Vector3.UP * HEAD_HEIGHT
	if unlocked and gauntlet.spend(self, contact):
		power()
	else:
		_clank()


## Power up (also callable directly, e.g. from a test or a script).
func power() -> void:
	if is_powered:
		return
	is_powered = true
	_apply_lamp()
	GameFeel.impact(global_position + Vector3.UP * HEAD_HEIGHT, Color(LIVE_LAMP, 0.7), 1.6, 0.3)
	var t := target_node()
	if t != null:
		if t.has_method(&"power"):
			t.call(&"power")
		elif t.has_method(&"open"):
			t.call(&"open")
	powered.emit()


func _clank() -> void:
	GameFeel.impact(global_position + Vector3.UP * HEAD_HEIGHT, Color(0.6, 0.55, 0.5, 0.5), 0.6, 0.12)
	if _head != null:
		var tw := create_tween()
		tw.tween_property(_head, "rotation:z", 0.12, 0.05)
		tw.tween_property(_head, "rotation:z", 0.0, 0.15)
	clanked.emit()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _visual != null:
		_visual.queue_free()
	_visual = Node3D.new()
	_visual.name = "TerminalVisual"
	add_child(_visual)
	var dark := COPPER.darkened(0.35)
	_box(Vector3(0.8, 0.2, 0.8), Vector3(0, 0.1, 0), _flat(dark))
	var post := Block.new()
	post.name = "Post"
	post.size = Vector3(0.35, POST_HEIGHT, 0.35)
	post.color = COPPER
	post.position.y = POST_HEIGHT * 0.5
	_visual.add_child(post)
	_head = _box(Vector3(0.6, 0.35, 0.6), Vector3(0, HEAD_HEIGHT - 0.1, 0), _flat(dark))
	# Copper coil rings round the post.
	for y: float in [0.45, 0.7, 0.95]:
		var ring := CylinderMesh.new()
		ring.top_radius = 0.26
		ring.bottom_radius = 0.26
		ring.height = 0.07
		_mesh(ring, Vector3(0, y, 0), _flat(COPPER.lightened(0.15), 0.6))
	_lamp_material = _flat(DEAD_LAMP, 0.0)
	_lamp_material.emission_enabled = true
	_lamp_material.emission = Color.BLACK
	var lamp := SphereMesh.new()
	lamp.radius = 0.22
	lamp.height = 0.44
	_mesh(lamp, Vector3(0, HEAD_HEIGHT + 0.25, 0), _lamp_material)
	_cable_material = _flat(Color(0.2, 0.17, 0.15), 0.0)
	_cable_material.emission_enabled = true
	_cable_material.emission = Color.BLACK
	var t := target_node() as Node3D
	if t != null:
		var to := to_local(t.global_position)
		to.y = 0.0
		if to.length() > 0.5:
			var cable := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.12, 0.04, to.length())
			cable.mesh = box
			cable.material_override = _cable_material
			_visual.add_child(cable)
			cable.transform = Transform3D(Basis.looking_at(to.normalized(), Vector3.UP), to * 0.5 + Vector3.UP * 0.03)
	_apply_lamp()


func _apply_lamp() -> void:
	if _lamp_material == null:
		return
	_lamp_material.albedo_color = LIVE_LAMP if is_powered else DEAD_LAMP
	_lamp_material.emission = LIVE_LAMP * 2.5 if is_powered else Color.BLACK
	_cable_material.albedo_color = LIVE_LAMP if is_powered else Color(0.2, 0.17, 0.15)
	_cable_material.emission = LIVE_LAMP * 1.5 if is_powered else Color.BLACK


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _mesh(box, pos, mat)


func _mesh(mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	_visual.add_child(mi)
	return mi


func _flat(c: Color, metallic: float = 0.3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = 0.5
	return m
