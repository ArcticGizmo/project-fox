class_name Glimmer
extends Node3D
## One loose mote of glimmer (the currency). `spill()` pops a pile out of a
## defeated enemy, a crate or a jar: motes arc out, bounce, hover, then fly to
## the fox once she is within PlayerTuning.glimmer_magnet_radius and pay out on
## contact. Bigger denominations are bigger and change colour. Uncollected motes
## blink and vanish after LIFETIME.

const GROUP := &"glimmer"
## spill() pays out greedily, biggest denomination first.
const DENOMINATIONS: Array[int] = [100, 25, 5, 1]
## Denomination -> [radius, colour].
const LOOKS: Dictionary = {
	1: [0.07, Color(0.45, 1.0, 0.88)],
	5: [0.1, Color(0.55, 0.75, 1.0)],
	25: [0.13, Color(0.8, 0.55, 1.0)],
	100: [0.17, Color(1.0, 0.9, 1.0)],
}
const GRAVITY := 20.0
const HOVER := 0.35
const COLLECT_DELAY := 0.35
const COLLECT_DISTANCE := 0.7
const LIFETIME := 30.0
const BLINK_TIME := 4.0

static var _meshes: Dictionary = {}

var value: int = 1
var velocity: Vector3 = Vector3.ZERO
var age: float = 0.0
var magnetised: bool = false

var _ground_y: float = -INF
var _ground_found: bool = false
var _settled: bool = false
var _speed: float = 0.0
var _mesh: MeshInstance3D


## Scatters `amount` of glimmer as motes at `at` under `parent`. Returns the motes.
static func spill(parent: Node, at: Vector3, amount: int, seed_value: int = 0) -> Array[Glimmer]:
	var out: Array[Glimmer] = []
	if parent == null or amount <= 0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else hash(at)
	var left := amount
	for d: int in DENOMINATIONS:
		while left >= d:
			left -= d
			var g := Glimmer.new()
			g.value = d
			var a := rng.randf() * TAU
			var out_speed := rng.randf_range(1.5, 3.5)
			g.velocity = Vector3(cos(a) * out_speed, rng.randf_range(4.5, 7.0), sin(a) * out_speed)
			parent.add_child(g)
			g.global_position = at
			out.append(g)
	return out


## Total value of the given motes.
static func total(motes: Array[Glimmer]) -> int:
	var sum := 0
	for g: Glimmer in motes:
		sum += g.value
	return sum


func _ready() -> void:
	add_to_group(GROUP)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _mesh_for(value)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


## Where the mote comes to rest (WORLD below it). Found on its first physics
## frame, not at spill time, which can be mid physics callback.
func _find_ground() -> void:
	_ground_found = true
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.5, global_position + Vector3.DOWN * 30.0, Layers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	_ground_y = (hit["position"] as Vector3).y if not hit.is_empty() else -INF


func _physics_process(delta: float) -> void:
	if not _ground_found:
		_find_ground()
	age += delta
	if age >= LIFETIME:
		queue_free()
		return
	var player := _player()
	if player != null and age >= COLLECT_DELAY:
		var target := player.global_position + Vector3.UP * 0.9
		var to := target - global_position
		if magnetised or to.length() <= player.tuning.glimmer_magnet_radius:
			magnetised = true
			if to.length() <= COLLECT_DISTANCE:
				_collect(player)
				return
			_speed = minf(player.tuning.glimmer_magnet_speed, _speed + player.tuning.glimmer_magnet_accel * delta)
			global_position += to.normalized() * minf(_speed * delta, to.length())
			_animate(delta)
			return
	if not _settled:
		velocity.y -= GRAVITY * delta
		global_position += velocity * delta
		var floor_y := _ground_y + HOVER
		if global_position.y <= floor_y and velocity.y < 0.0:
			global_position.y = floor_y
			if absf(velocity.y) < 2.0:
				_settled = true
			velocity = Vector3(velocity.x * 0.5, -velocity.y * 0.35, velocity.z * 0.5)
	_animate(delta)


func is_settled() -> bool:
	return _settled


func _animate(delta: float) -> void:
	rotate_y(delta * 3.0)
	_mesh.position.y = sin(age * 4.0 + value) * 0.05 if _settled and not magnetised else 0.0
	_mesh.visible = age < LIFETIME - BLINK_TIME or fmod(age, 0.2) < 0.12


func _collect(player: Player) -> void:
	player.add_glimmer(value)
	Sfx.play(&"glimmer", null, -3.0 if value < 25 else 0.0)
	queue_free()


func _player() -> Player:
	var p := get_tree().get_first_node_in_group(&"player") as Player
	return p if p != null and not p.is_dead else null


static func _mesh_for(denomination: int) -> Mesh:
	if _meshes.has(denomination):
		return _meshes[denomination] as Mesh
	var look: Array = LOOKS.get(denomination, LOOKS[1])
	var r: float = look[0]
	var c: Color = look[1]
	# A diamond: a sphere cut to 4 sides and 2 rings is an octahedron.
	var mesh := SphereMesh.new()
	mesh.radial_segments = 4
	mesh.rings = 1
	mesh.radius = r
	mesh.height = r * 2.8
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = 2.5
	mesh.material = mat
	_meshes[denomination] = mesh
	return mesh
