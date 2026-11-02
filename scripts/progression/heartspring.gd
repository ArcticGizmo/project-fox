@tool
class_name Heartspring
extends SavedPickup
## A wound brass spring round a glowing heart gem, hidden off the main path.
## Touch it: +PlayerTuning.heartspring_health max health and a full heal. Saved
## (SavedPickup), so each one is found once per save.

const COLOR := Color(1.0, 0.35, 0.45)
const BRASS := Color(0.85, 0.65, 0.3)
const RADIUS := 0.9
const FLOAT_HEIGHT := 1.0

var _visual: Node3D
var _t: float = 0.0


func _ready() -> void:
	_visual = Node3D.new()
	_visual.position.y = FLOAT_HEIGHT
	add_child(_visual)
	var gem := MeshInstance3D.new()
	var heart := SphereMesh.new()
	heart.radius = 0.22
	heart.height = 0.44
	gem.mesh = heart
	gem.scale = Vector3(1.0, 1.15, 0.7)
	gem.material_override = _mat(COLOR, 3.0)
	_visual.add_child(gem)
	# The spring: brass rings stacked round the gem, tilted alternately.
	for i: int in 4:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.3
		torus.outer_radius = 0.36
		ring.mesh = torus
		ring.position.y = -0.27 + i * 0.18
		ring.rotation.x = 0.18 * (1 if i % 2 == 0 else -1)
		ring.material_override = _mat(BRASS, 0.0)
		_visual.add_child(ring)
	var light := OmniLight3D.new()
	light.light_color = COLOR
	light.light_energy = 1.2
	light.omni_range = 3.5
	_visual.add_child(light)
	if Engine.is_editor_hint():
		return
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = Layers.PLAYER
	area.monitorable = false
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = RADIUS
	cs.shape = shape
	cs.position.y = FLOAT_HEIGHT
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_on_body_entered)


func kind() -> StringName:
	return &"heartspring"


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	_visual.rotation.y = _t * 1.6
	_visual.position.y = FLOAT_HEIGHT + sin(_t * 2.2) * 0.12


func _on_body_entered(body: Node3D) -> void:
	var p := body as Player
	if p == null or p.is_dead or is_taken:
		return
	p.add_heartspring()
	Sfx.play(&"heartspring")
	GameFeel.impact(_visual.global_position, COLOR, 2.5, 0.4)
	GameFeel.rumble(0.4, 0.3, 0.25)
	_take()
	queue_free()


func _mat(c: Color, glow: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.35
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	else:
		m.metallic = 0.6
	return m
