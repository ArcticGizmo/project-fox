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
##   conduit = a copper door: banded faces and a row of dead lamps. A powered
##             ConduitTerminal whose `target` is this gate calls power(): the
##             lamps light and the door sinks into the floor (collision follows)
##             and stays open (player respawns reset enemies, not doors).

## Conduit doors: emitted when the door starts opening.
signal opened

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
## Conduit doors: seconds to sink into the floor once powered.
const DOOR_OPEN_TIME := 1.2
## Conduit doors: powered and opening / open (true once power() is called).
var is_open: bool = false
var _deco: Node3D
var _lamp_material: StandardMaterial3D
var _label: Label3D
var _door_tween: Tween


## Conduit doors are open once powered (the gadget alone doesn't open them);
## every other gate is passable with its gadget.
func is_open_for(player: Player) -> bool:
	if requires == Gadgets.CONDUIT:
		return is_open
	return player != null and player.has_gadget(requires)


## Conduit doors (ConduitTerminal target): light the lamps and sink into the
## floor over DOOR_OPEN_TIME. The body moves, so its collision follows.
func power() -> void:
	open()


func open() -> void:
	if is_open:
		return
	is_open = true
	if _lamp_material != null:
		_lamp_material.emission = Color(0.55, 0.85, 1.0) * 2.5
		_lamp_material.albedo_color = Color(0.55, 0.85, 1.0)
	if _label != null:
		_label.visible = false
	_door_tween = create_tween()
	_door_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_door_tween.tween_interval(0.25)
	# Just below flush, so the sunk top doesn't z-fight the floor it sits in.
	_door_tween.tween_property(self, "position:y", position.y - size.y - 0.02, DOOR_OPEN_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	GameFeel.shake(0.2)
	opened.emit()


## Conduit doors: true once fully sunk.
func is_fully_open() -> bool:
	return is_open and (_door_tween == null or not _door_tween.is_running())


func _display_color() -> Color:
	return GATE_COLORS.get(requires, UNKNOWN_COLOR)


func _decorate() -> void:
	if _deco != null:
		_deco.queue_free()
	ring = null
	vent = null
	soil = null
	_lamp_material = null
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
			_decorate_door(c)
	var label := Label3D.new()
	label.text = "%s gate" % String(requires) if GATE_COLORS.has(requires) else "? gate"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.outline_size = 10
	label.pixel_size = 0.01
	label.modulate = c.lightened(0.4)
	label.position.y = 3.3 if requires == &"grapple" else 2.4  # clear of the ring and its pip
	_deco.add_child(label)
	_label = label
	if is_open:
		label.visible = false


## Copper door: dark bands and a seam on both broad faces, a row of dead lamps
## near the top (lit by power()).
func _decorate_door(c: Color) -> void:
	_lamp_material = StandardMaterial3D.new()
	_lamp_material.albedo_color = Color(0.22, 0.26, 0.3) if not is_open else Color(0.55, 0.85, 1.0)
	_lamp_material.emission_enabled = true
	_lamp_material.emission = Color.BLACK if not is_open else Color(0.55, 0.85, 1.0) * 2.5
	var thin_x := size.x <= size.z
	var thick := (size.x if thin_x else size.z) * 0.5 + 0.03
	var wide := size.z if thin_x else size.x
	var lamp := SphereMesh.new()
	lamp.radius = 0.16
	lamp.height = 0.32
	for side: float in [-1.0, 1.0]:
		for i: int in 3:
			var along := (float(i) - 1.0) * wide * 0.3
			var pos := Vector3(side * thick, -0.6, along) if thin_x else Vector3(along, -0.6, side * thick)
			var mi := _mesh_at(lamp, pos, Color.WHITE)
			mi.material_override = _lamp_material
		for along: float in [-wide * 0.45, 0.0, wide * 0.45]:
			var band := BoxMesh.new()
			band.size = Vector3(0.06, size.y * 0.96, 0.18 if along != 0.0 else 0.08) if thin_x else Vector3(0.18 if along != 0.0 else 0.08, size.y * 0.96, 0.06)
			var bpos := Vector3(side * thick, -size.y * 0.5, along) if thin_x else Vector3(along, -size.y * 0.5, side * thick)
			_mesh_at(band, bpos, c.darkened(0.45))
		var bar := BoxMesh.new()
		bar.size = Vector3(0.06, 0.2, wide * 0.95) if thin_x else Vector3(wide * 0.95, 0.2, 0.06)
		_mesh_at(bar, Vector3(side * thick, -size.y * 0.55, 0) if thin_x else Vector3(0, -size.y * 0.55, side * thick), c.darkened(0.45))


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
