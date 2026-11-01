@tool
class_name SoilPatch
extends Node3D
## A patch of loose soil the Burrow Claws dig into (see BurrowClaws). The origin
## is the centre of the surface; the patch is a flat disc of `radius`. Purely
## visual (no collision): without the gadget it is ground decor.
##
## A patch linked to another (`exit`, either side may set it) is a tunnel:
## dodging while burrowed travels to the partner. A standalone patch only lets
## you move about under it and pop out again (ambushes). Underground movement
## never leaves the patch you are under, so level design stays controllable.
## Keep patches away from lava (a burrowed fox ignores damage, not launches).

const GROUP := &"soil_patches"
const SOIL_COLOR := Color(0.36, 0.23, 0.12)
const LUMP_COLOR := Color(0.27, 0.17, 0.09)
## A fox counts as on the patch with its feet this close to the surface (height).
const HEIGHT_TOLERANCE := 0.5

@export var radius: float = 1.5:
	set(value):
		radius = value
		_rebuild()
## Partner patch (a tunnel). May point at a SoilPatch or at a burrow GadgetGate
## (its `soil`). Leave empty for a standalone patch.
@export var exit: NodePath
## Resolve `exit` relative to this node instead (GadgetGate sets it to itself).
var exit_owner: Node

var _visual: Node3D
var _partner: SoilPatch


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group(GROUP)
	_rebuild()


## True when a fox with its feet at `pos` stands on this patch.
func contains(pos: Vector3, margin: float = 0.0) -> bool:
	var local := pos - global_position
	if absf(local.y) > HEIGHT_TOLERANCE:
		return false
	return Vector2(local.x, local.z).length() <= radius - margin


## `pos` pulled back inside the patch (flat), `margin` in from the edge.
func confine(pos: Vector3, margin: float) -> Vector3:
	var local := pos - global_position
	var flat := Vector2(local.x, local.z)
	var limit := maxf(radius - margin, 0.0)
	if flat.length() <= limit:
		return pos
	flat = flat.normalized() * limit
	return Vector3(global_position.x + flat.x, pos.y, global_position.z + flat.y)


## The patch a fox with its feet at `pos` stands on, or null.
static func at(tree: SceneTree, pos: Vector3) -> SoilPatch:
	for n: Node in tree.get_nodes_in_group(GROUP):
		var p := n as SoilPatch
		if p != null and p.is_visible_in_tree() and p.contains(pos):
			return p
	return null


## The linked patch (tunnel exit), or null for a standalone patch. Either side
## of the link may set `exit`.
func partner() -> SoilPatch:
	if _partner != null and is_instance_valid(_partner) and _partner.is_inside_tree():
		return _partner
	_partner = _resolve_exit()
	if _partner == null and is_inside_tree():
		for n: Node in get_tree().get_nodes_in_group(GROUP):
			var other := n as SoilPatch
			if other != null and other != self and other._resolve_exit() == self:
				_partner = other
				break
	return _partner


func _resolve_exit() -> SoilPatch:
	if exit.is_empty() or not is_inside_tree():
		return null
	var base: Node = exit_owner if exit_owner != null else self
	var n := base.get_node_or_null(exit)
	if n is SoilPatch:
		return n as SoilPatch
	if n != null and n.get(&"soil") is SoilPatch:
		return n.get(&"soil") as SoilPatch
	return null


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _visual != null:
		_visual.queue_free()
	_visual = Node3D.new()
	_visual.name = "Soil"
	add_child(_visual)
	# A low dark disc of turned earth with lumps round its rim (flat in the middle,
	# so the lighter dirt mound of a burrowed fox stands out on it).
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius + 0.1
	disc.height = 0.08
	_mesh(disc, Vector3(0, 0.04, 0), SOIL_COLOR)
	var lumps := 7
	for i: int in lumps:
		var a := TAU * float(i) / lumps + 0.4
		var lump := SphereMesh.new()
		lump.radius = 0.16 + 0.05 * float(i % 3)
		lump.height = lump.radius * 1.1
		lump.radial_segments = 8
		lump.rings = 4
		_mesh(lump, Vector3(cos(a), 0, sin(a)) * radius * (0.6 + 0.12 * float(i % 2)) + Vector3.UP * 0.07, LUMP_COLOR)


func _mesh(mesh: Mesh, pos: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 1.0
	mi.material_override = mat
	_visual.add_child(mi)
