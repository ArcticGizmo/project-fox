@tool
class_name GravityRift
extends Node3D
## A magical zone (level feature, not a gadget) where gravity is replaced by a
## pull of `pull` m/s^2 along the rift's local -Y. Rotate it to aim the pull:
## upright-inverted (local -Y pointing up) is a rift lift that floats you up a
## cliff, tipped on its side it is a rift current that carries you across a gap.
## The fox stays upright (no wall-walking): inside, the player's gravity step
## becomes `accelerate(velocity, delta)`, capped at `max_speed` along the pull,
## and the sideways part rides on top of normal movement as drift. Enemies
## (non-flying) drift too. Chevrons inside scroll along the pull direction.
## `size` is in the rift's own frame: size.y is always the length along the pull.
## Find one with GravityRift.at(tree, pos) (group "gravity_rifts").

const GROUP := &"gravity_rifts"
const COLOR := Color(0.55, 0.3, 0.9)
const CHEVRONS := 6

@export var size: Vector3 = Vector3(6, 6, 6):
	set(value):
		size = value
		_rebuild()
@export var pull: float = 14.0
## Top speed along the pull (the fox can still steer across it).
@export var max_speed: float = 8.0

var _mesh: MeshInstance3D
var _chevrons: Array[MeshInstance3D] = []
var _t: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	_rebuild()


static func at(tree: SceneTree, pos: Vector3) -> GravityRift:
	for n: Node in tree.get_nodes_in_group(GROUP):
		var r := n as GravityRift
		if r != null and r.is_visible_in_tree() and r.contains(pos):
			return r
	return null


func contains(pos: Vector3) -> bool:
	var local := global_transform.affine_inverse() * pos
	var half := size * 0.5
	return absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z


## World-space direction of the pull.
func gravity_direction() -> Vector3:
	return -global_basis.y.normalized()


## `velocity` after `delta` seconds of pull (component along the pull capped at max_speed).
func accelerate(velocity: Vector3, delta: float) -> Vector3:
	var dir := gravity_direction()
	var along := velocity.dot(dir)
	var gain := minf(pull * delta, maxf(0.0, max_speed - along))
	return velocity + dir * gain


func _process(delta: float) -> void:
	_t += delta
	var travel := size.y
	for i: int in _chevrons.size():
		var c := _chevrons[i]
		var u := fmod(_t * 0.6 + float(i) / _chevrons.size(), 1.0)
		# Local -Y is the pull: chevrons stream from +Y to -Y.
		c.position = Vector3(0, travel * (0.5 - u), 0)
		var mat := c.material_override as StandardMaterial3D
		mat.albedo_color.a = 0.55 * sin(u * PI)


func _rebuild() -> void:
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		add_child(_mesh, false, Node.INTERNAL_MODE_FRONT)
	var box := BoxMesh.new()
	box.size = size
	_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(COLOR, 0.14)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh.material_override = mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c: MeshInstance3D in _chevrons:
		c.queue_free()
	_chevrons.clear()
	for i: int in CHEVRONS:
		var chevron := MeshInstance3D.new()
		chevron.mesh = _chevron_mesh(minf(size.x, size.z) * 0.6)
		var cm := StandardMaterial3D.new()
		cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cm.albedo_color = Color(COLOR.lightened(0.4), 0.5)
		cm.cull_mode = BaseMaterial3D.CULL_DISABLED
		chevron.material_override = cm
		chevron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(chevron, false, Node.INTERNAL_MODE_FRONT)
		_chevrons.append(chevron)


## A flat "V" pointing along local -Y, seen from both sides (two crossed planes).
static func _chevron_mesh(width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := width * 0.5
	var h := width * 0.35
	var t := width * 0.08
	for axis: int in 2:
		var side := Vector3(1, 0, 0) if axis == 0 else Vector3(0, 0, 1)
		for s: float in [-1.0, 1.0]:
			var outer := side * s * w + Vector3.UP * h
			var tip := Vector3.ZERO
			st.add_vertex(tip)
			st.add_vertex(outer)
			st.add_vertex(outer + Vector3.UP * t)
			st.add_vertex(tip)
			st.add_vertex(outer + Vector3.UP * t)
			st.add_vertex(tip + Vector3.UP * t)
	return st.commit()
