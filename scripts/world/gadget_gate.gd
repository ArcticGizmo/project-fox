@tool
class_name GadgetGate
extends Block
## A Block that marks a spot only a gadget gets past: a per-gadget colour, a
## marker primitive on top and a label. Gadget behaviour reads `requires` and
## `is_open_for()`.
##   grapple = a real GrappleRing (`ring`) RING_HEIGHT above the top: the
##             Grapple-Tail reels the fox onto this block.
##   glide = a real SteamVent (`vent`) updraft on top.
##   burrow = a real SoilPatch (`soil`) on top, tunnelling to the `link` gate.
##   conduit = copper terminal (task 8).

const GATE_COLORS: Dictionary = {
	&"grapple": Color(0.78, 0.6, 0.25),
	&"glide": Color(0.62, 0.85, 0.66),
	&"burrow": Color(0.42, 0.28, 0.16),
	&"conduit": Color(0.78, 0.42, 0.24),
}
const UNKNOWN_COLOR := Color(0.4, 0.4, 0.4)

## Gadget id (see Gadgets.ALL): &"grapple", &"glide", &"burrow" or &"conduit".
@export var requires: StringName = &"grapple":
	set(value):
		requires = value
		_rebuild()

## Height of the grapple ring above the gate's top face.
const RING_HEIGHT := 1.4

## The anchor built on top of a grapple gate (null for other gadgets).
var ring: GrappleRing
## Updraft column height above a glide gate.
const VENT_LIFT_HEIGHT := 10.0
## The updraft built on a glide gate (null for other gadgets).
var vent: SteamVent
## Burrow gates: the partner gate (or SoilPatch) this one tunnels to. Either
## side of a pair may set it.
@export var link: NodePath:
	set(value):
		link = value
		if soil != null:
			soil.exit = value
## The soil patch built on a burrow gate's top (null for other gadgets).
var soil: SoilPatch
var _deco: Node3D


func is_open_for(player: Player) -> bool:
	return player != null and player.has_gadget(requires)


func _display_color() -> Color:
	return GATE_COLORS.get(requires, UNKNOWN_COLOR)


func _decorate() -> void:
	if _deco != null:
		_deco.queue_free()
	ring = null
	vent = null
	soil = null
	_deco = Node3D.new()
	_deco.name = "GateMarker"
	_deco.position.y = size.y * 0.5
	add_child(_deco)
	var c := _display_color()
	match requires:
		&"grapple":
			# A real anchor: the Grapple-Tail reels the fox up to it (and onto this top).
			ring = GrappleRing.new()
			ring.name = "GrappleRing"
			ring.position = Vector3(0, RING_HEIGHT, 0)
			_deco.add_child(ring)
		&"glide":
			for i: int in 3:
				var slat := BoxMesh.new()
				slat.size = Vector3(minf(size.x, 2.5) * 0.8, 0.08, 0.18)
				_mesh_at(slat, Vector3(0, 0.05, (i - 1) * 0.4), Color(0.15, 0.2, 0.17))
			# A real updraft: the Leaf-wing Cloak rides it up (SteamVent).
			vent = SteamVent.new()
			vent.name = "SteamVent"
			vent.radius = minf(size.x, size.z) * 0.5 + 0.2
			vent.lift_height = VENT_LIFT_HEIGHT
			vent.position.y = 0.1
			_deco.add_child(vent)
		&"burrow":
			# A real patch: the Burrow Claws dig in here (and tunnel to `link`).
			soil = SoilPatch.new()
			soil.name = "SoilPatch"
			soil.radius = minf(size.x, size.z) * 0.5
			soil.exit = link
			soil.exit_owner = self
			_deco.add_child(soil)
		&"conduit":
			_mesh_at(_cylinder(0.18, 1.0), Vector3(0, 0.5, 0), c.darkened(0.2))
			var cap := SphereMesh.new()
			cap.radius = 0.28
			cap.height = 0.56
			_mesh_at(cap, Vector3(0, 1.1, 0), c.lightened(0.3), 0.4)
	var label := Label3D.new()
	label.text = "%s gate" % String(requires) if GATE_COLORS.has(requires) else "? gate"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.outline_size = 10
	label.pixel_size = 0.01
	label.modulate = c.lightened(0.4)
	label.position.y = 3.3 if requires == &"grapple" else 2.4  # clear of the ring and its pip
	_deco.add_child(label)


func _cylinder(radius: float, height: float) -> CylinderMesh:
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	return cyl


func _mesh_at(mesh: Mesh, pos: Vector3, c: Color, glow: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.6
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = Color(c.r, c.g, c.b) * glow
	mi.material_override = mat
	_deco.add_child(mi)
	return mi
