@tool
class_name GadgetGate
extends Block
## A Block that marks a spot only a gadget gets past. For now it is only a
## visible "not yet": a per-gadget colour, a marker primitive on top and a label.
## Gadget behaviour (tasks 5-8) will read `requires` and `is_open_for()`.
##   grapple = brass ring, glide = pale green vent, burrow = brown soil mound,
##   conduit = copper terminal.

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

var _deco: Node3D


func is_open_for(player: Player) -> bool:
	return player != null and player.has_gadget(requires)


func _display_color() -> Color:
	return GATE_COLORS.get(requires, UNKNOWN_COLOR)


func _decorate() -> void:
	if _deco != null:
		_deco.queue_free()
	_deco = Node3D.new()
	_deco.name = "GateMarker"
	_deco.position.y = size.y * 0.5
	add_child(_deco)
	var c := _display_color()
	match requires:
		&"grapple":
			var ring := TorusMesh.new()
			ring.inner_radius = 0.45
			ring.outer_radius = 0.6
			var m := _mesh_at(ring, Vector3(0, 1.4, 0), c.lightened(0.25), 0.6)
			m.rotation.x = PI * 0.5
			_mesh_at(_cylinder(0.06, 0.8), Vector3(0, 0.4, 0), c.darkened(0.3))
		&"glide":
			for i: int in 3:
				var slat := BoxMesh.new()
				slat.size = Vector3(minf(size.x, 2.5) * 0.8, 0.08, 0.18)
				_mesh_at(slat, Vector3(0, 0.05, (i - 1) * 0.4), Color(0.15, 0.2, 0.17))
			var plume := CylinderMesh.new()
			plume.top_radius = 0.7
			plume.bottom_radius = 0.5
			plume.height = 2.0
			var p := _mesh_at(plume, Vector3(0, 1.1, 0), Color(c, 0.25), 0.3)
			(p.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		&"burrow":
			var mound := SphereMesh.new()
			mound.radius = 0.9
			mound.height = 0.6
			_mesh_at(mound, Vector3(0, 0.1, 0), c.darkened(0.25))
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
	label.position.y = 2.4
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
