class_name VenomGlob
extends Node3D
## A lobbed glob of venom. On impact it splashes (stats.damage, small radius)
## and leaves a puddle; enemies standing in the puddle gain poison stacks
## every TICK seconds. Contagious puddles make the poison spread on death.

enum State { FLYING, PUDDLE }

const GRAVITY := PufferMine.GRAVITY
const TICK := 0.5
const SPLASH_RADIUS := 1.2

var weapon: Weapon = null
var velocity: Vector3 = Vector3.ZERO
var damage: float = 10.0
var radius: float = 2.5
var lifetime: float = 4.0
var stacks_per_tick: int = 1
var contagious: bool = false
var color: Color = Color(0.55, 0.85, 0.2)
var state: State = State.FLYING

var _t: float = 0.0
var _tick: float = 0.0
var _glob: MeshInstance3D
var _puddle: MeshInstance3D
var _puddle_mat: StandardMaterial3D


func _ready() -> void:
	_glob = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	_glob.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.5
	_glob.material_override = mat
	add_child(_glob)


func _physics_process(delta: float) -> void:
	_t += delta
	if state == State.FLYING:
		_fly(delta)
		return
	_puddle_mat.albedo_color.a = 0.45 * clampf((lifetime - _t) / 0.5, 0.0, 1.0)
	_tick += delta
	if _tick >= TICK:
		_tick -= TICK
		for e: Enemy in Enemy.in_radius(get_tree(), global_position, radius):
			if absf(e.global_position.y - global_position.y) < 1.5:
				e.add_poison(stacks_per_tick, weapon, contagious)
	if _t >= lifetime:
		queue_free()


func _fly(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD | Layers.ENEMY_HURTBOX)
	q.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = to
		return
	_splash(hit["position"] as Vector3)


func _splash(at: Vector3) -> void:
	Explosion.detonate(self, at, SPLASH_RADIUS, Layers.ENEMY_HURTBOX, _make_damage)
	GameFeel.impact(at, color, 1.5, 0.2)
	# Settle on the ground below the impact point.
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 20.0, Layers.WORLD)
	var ground := get_world_3d().direct_space_state.intersect_ray(q)
	global_position = at if ground.is_empty() else (ground["position"] as Vector3)
	_glob.visible = false
	_puddle = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.04
	_puddle.mesh = disc
	_puddle_mat = StandardMaterial3D.new()
	_puddle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_puddle_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_puddle_mat.albedo_color = Color(color, 0.45)
	_puddle.material_override = _puddle_mat
	_puddle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_puddle.position.y = 0.03
	add_child(_puddle)
	state = State.PUDDLE
	_t = 0.0
	_tick = TICK  # poison anything already standing in it straight away


func _make_damage() -> DamageInfo:
	if is_instance_valid(weapon):
		return weapon.make_damage(damage, global_position)
	return DamageInfo.create(damage, global_position)
