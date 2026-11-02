@tool
class_name MagpiePeddler
extends Node3D
## A clockwork magpie's stall: the vendor. It sells the weapons the fox doesn't
## own and ammo refills for glimmer (Shop, ShopMenu). Strike the brass bell on
## the counter with the staff to trade (the bell carries a ConduitSocket, so
## only the staff swing rings it; no new button). A prompt floats over the
## counter while the fox is near. LevelRoot connects `trade_requested` to its
## ShopMenu.
##
## The stall faces its local -Z: the fox walks up on that side, the magpie
## perches behind the counter. Origin at floor level; the counter is solid.

signal trade_requested(peddler: MagpiePeddler)

const GROUP := &"peddlers"
const PROMPT_RADIUS := 6.0
const RING_COOLDOWN := 0.6
const BRASS := Color(0.85, 0.65, 0.3)
const WOOD := Color(0.42, 0.28, 0.18)
const FEATHER := Color(0.07, 0.07, 0.09)
const SHEEN := Color(0.12, 0.32, 0.5)
const COUNTER_SIZE := Vector3(2.4, 1.0, 0.8)
## Bell position on the counter (local).
const BELL_POS := Vector3(0.85, 1.35, -0.15)

var prompt: Label3D
var socket: ConduitSocket
var rings: int = 0

var _bell: Node3D
var _bird: Node3D
var _head: Node3D
var _t: float = 0.0
var _ring_left: float = 0.0
var _cooldown: float = 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group(GROUP)
	_build()


func _build() -> void:
	# Counter (solid) with a brass trim.
	var body := StaticBody3D.new()
	body.name = "Counter"
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = COUNTER_SIZE
	cs.shape = box
	cs.position.y = COUNTER_SIZE.y * 0.5
	body.add_child(cs)
	add_child(body)
	_box(self, COUNTER_SIZE, Vector3(0, COUNTER_SIZE.y * 0.5, 0), WOOD)
	_box(self, Vector3(COUNTER_SIZE.x + 0.1, 0.08, COUNTER_SIZE.z + 0.1), Vector3(0, COUNTER_SIZE.y, 0), BRASS, true)
	# Canopy: two back posts and a striped awning.
	for x: float in [-1.2, 1.2]:
		_box(self, Vector3(0.12, 2.7, 0.12), Vector3(x, 1.35, 0.9), WOOD)
	for i: int in 5:
		var c := Color(0.2, 0.55, 0.55) if i % 2 == 0 else Color(0.92, 0.86, 0.7)
		var stripe := _box(self, Vector3(0.56, 0.06, 1.9), Vector3(-1.12 + i * 0.56, 2.65, 0.2), c)
		stripe.rotation.x = -0.25
	# Hanging sign: a brass cog.
	var cog := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.28
	disc.bottom_radius = 0.28
	disc.height = 0.06
	cog.mesh = disc
	cog.material_override = _mat(BRASS, true)
	cog.rotation.x = PI * 0.5
	cog.position = Vector3(0, 2.25, -0.72)
	add_child(cog)
	_build_bell()
	_build_bird()
	if Engine.is_editor_hint():
		return
	socket = ConduitSocket.make(self, "BellSocket", Vector3(0.8, 1.2, 0.8), BELL_POS + Vector3(0, -0.2, 0), self)
	prompt = Label3D.new()
	prompt.text = "Strike the bell to trade  (X / F)"
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt.no_depth_test = true
	prompt.fixed_size = false
	prompt.pixel_size = 0.004
	prompt.font_size = 44
	prompt.outline_size = 10
	prompt.modulate = Color(1, 0.92, 0.7)
	prompt.position = Vector3(0, 3.2, -0.3)
	prompt.visible = false
	add_child(prompt)


func _build_bell() -> void:
	_box(self, Vector3(0.05, 0.5, 0.05), Vector3(BELL_POS.x + 0.22, COUNTER_SIZE.y + 0.25, BELL_POS.z), BRASS, true)
	_box(self, Vector3(0.3, 0.04, 0.04), Vector3(BELL_POS.x + 0.1, COUNTER_SIZE.y + 0.5, BELL_POS.z), BRASS, true)
	_bell = Node3D.new()
	_bell.name = "Bell"
	_bell.position = Vector3(BELL_POS.x, COUNTER_SIZE.y + 0.48, BELL_POS.z)
	add_child(_bell)
	var cup := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.05
	cone.bottom_radius = 0.14
	cone.height = 0.2
	cup.mesh = cone
	cup.position.y = -0.12
	cup.material_override = _mat(BRASS, true)
	_bell.add_child(cup)


## The magpie: black body and head, white belly and wing patches, a long
## blue-green tail, a brass monocle. Looks along -Z.
func _build_bird() -> void:
	_box(self, Vector3(0.08, 1.2, 0.08), Vector3(0, 0.6, 0.75), BRASS, true)
	_box(self, Vector3(0.5, 0.06, 0.08), Vector3(0, 1.2, 0.75), BRASS, true)
	_bird = Node3D.new()
	_bird.name = "Magpie"
	_bird.position = Vector3(0, 1.23, 0.75)
	add_child(_bird)
	_sphere(_bird, 0.26, Vector3(0, 0.3, 0), Vector3(0.9, 0.85, 1.25), FEATHER)
	_sphere(_bird, 0.19, Vector3(0, 0.25, -0.17), Vector3(0.9, 1.0, 0.8), Color(0.93, 0.93, 0.9))
	for side: float in [-1.0, 1.0]:
		_sphere(_bird, 0.15, Vector3(side * 0.2, 0.33, 0.05), Vector3(0.45, 0.8, 1.5), SHEEN)
		_sphere(_bird, 0.07, Vector3(side * 0.25, 0.33, 0.0), Vector3(0.5, 0.9, 1.4), Color(0.93, 0.93, 0.9))
		_box(_bird, Vector3(0.03, 0.12, 0.03), Vector3(side * 0.08, 0.04, 0.0), Color(0.2, 0.2, 0.22))
	var tail := _box(_bird, Vector3(0.14, 0.04, 0.75), Vector3(0, 0.3, 0.6), SHEEN)
	tail.rotation.x = 0.35
	_head = Node3D.new()
	_head.position = Vector3(0, 0.6, -0.2)
	_bird.add_child(_head)
	_sphere(_head, 0.16, Vector3.ZERO, Vector3.ONE, FEATHER)
	var beak := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.045
	cone.height = 0.22
	beak.mesh = cone
	beak.rotation.x = -PI * 0.5
	beak.position = Vector3(0, -0.02, -0.22)
	beak.material_override = _mat(Color(0.25, 0.25, 0.28))
	_head.add_child(beak)
	for side: float in [-1.0, 1.0]:
		_sphere(_head, 0.03, Vector3(side * 0.09, 0.04, -0.12), Vector3.ONE, Color(0.9, 0.85, 0.6))
	var monocle := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.045
	ring.outer_radius = 0.06
	monocle.mesh = ring
	monocle.rotation.x = PI * 0.5
	monocle.position = Vector3(0.09, 0.04, -0.14)
	monocle.material_override = _mat(BRASS, true)
	_head.add_child(monocle)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	_cooldown = maxf(0.0, _cooldown - delta)
	# Idle: the head cocks side to side; a ring makes it hop and the bell swing.
	_head.rotation.z = sin(_t * 1.3) * 0.25 if fmod(_t, 4.0) < 2.5 else 0.0
	_ring_left = maxf(0.0, _ring_left - delta)
	var k := _ring_left / RING_COOLDOWN
	_bell.rotation.z = sin(k * 18.0) * 0.5 * k
	_bird.position.y = 1.23 + sin(k * PI) * 0.25
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	prompt.visible = player != null and player.global_position.distance_to(global_position) <= PROMPT_RADIUS \
			and not get_tree().paused


## Staff strike on the bell (ConduitSocket): ring and ask to trade.
func conduit_struck(_gauntlet: ConduitGauntlet, _unlocked: bool) -> void:
	ring()


func ring() -> void:
	if _cooldown > 0.0:
		return
	_cooldown = RING_COOLDOWN
	_ring_left = RING_COOLDOWN
	rings += 1
	Sfx.play(&"bell", _bell.global_position)
	trade_requested.emit(self)


func _mat(c: Color, metal: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.35 if metal else 0.7
	m.metallic = 0.7 if metal else 0.0
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, metal: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _mat(c, metal)
	parent.add_child(mi)
	return mi


func _sphere(parent: Node3D, r: float, pos: Vector3, squash: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mi.mesh = mesh
	mi.position = pos
	mi.scale = squash
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi
