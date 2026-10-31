class_name PufferMine
extends Node3D
## A lobbed pufferfish. Flies a ballistic arc; a direct hit on an enemy
## detonates immediately. Otherwise it lands, arms, and sits as a proximity
## mine: an enemy within TRIGGER_RADIUS (or the fuse running out) makes it
## puff up (telegraph) and explode.

enum State { FLYING, ARMING, ARMED, PRIMED }

const GRAVITY := 25.0
const ARM_TIME := 0.35
const PRIME_TIME := 0.3
const TRIGGER_RADIUS := 2.2
const BODY_RADIUS := 0.28

var weapon: Weapon = null
var velocity: Vector3 = Vector3.ZERO
var damage: float = 40.0
var blast_radius: float = 3.0
var knockback: float = 9.0
## Seconds an armed mine waits before detonating on its own.
var fuse: float = 5.0
var hit_mask: int = Layers.WORLD | Layers.ENEMY_HURTBOX
var color: Color = Color(0.95, 0.55, 0.7)
var state: State = State.FLYING

var _t: float = 0.0
var _body: MeshInstance3D
var _mat: StandardMaterial3D
var _trigger_shape: SphereShape3D


## Velocity that carries a projectile from `from` to `to` in `flight_time` under GRAVITY.
static func launch_velocity(from: Vector3, to: Vector3, flight_time: float) -> Vector3:
	return (to - from) / flight_time + Vector3.UP * 0.5 * GRAVITY * flight_time


static func flight_time_for(from: Vector3, to: Vector3) -> float:
	return clampf(from.distance_to(to) / 16.0, 0.45, 1.1)


func _ready() -> void:
	_body = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = BODY_RADIUS
	sphere.height = BODY_RADIUS * 2.0
	_body.mesh = sphere
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color
	_mat.emission_enabled = true
	_mat.emission = Color.BLACK
	_body.material_override = _mat
	add_child(_body)
	# Spines so it reads as a pufferfish.
	for d: Vector3 in [Vector3.UP, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var spine := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.06, 0.06, 0.06) + d.abs() * 0.18
		spine.mesh = box
		spine.material_override = _mat
		spine.position = d * BODY_RADIUS
		_body.add_child(spine)
	_trigger_shape = SphereShape3D.new()
	_trigger_shape.radius = TRIGGER_RADIUS


func _physics_process(delta: float) -> void:
	_t += delta
	match state:
		State.FLYING:
			_fly(delta)
		State.ARMING:
			if _t >= ARM_TIME:
				_enter(State.ARMED)
		State.ARMED:
			_body.position.y = sin(_t * 4.0) * 0.04
			if _t >= fuse or _enemy_in_range():
				_enter(State.PRIMED)
		State.PRIMED:
			var k := clampf(_t / PRIME_TIME, 0.0, 1.0)
			_body.scale = Vector3.ONE * (1.0 + 0.9 * k)
			_mat.emission = Color(1, 0.3, 0.2) * k
			if _t >= PRIME_TIME:
				detonate()


func _enter(s: State) -> void:
	state = s
	_t = 0.0


func _fly(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, hit_mask)
	q.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = to
		return
	if hit["collider"] is HurtBox:
		global_position = hit["position"]
		detonate()
		return
	global_position = (hit["position"] as Vector3) + (hit["normal"] as Vector3) * BODY_RADIUS
	velocity = Vector3.ZERO
	_enter(State.ARMING)


func _enemy_in_range() -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _trigger_shape
	params.transform = Transform3D(Basis.IDENTITY, global_position)
	params.collision_mask = Layers.ENEMY_HURTBOX
	params.collide_with_areas = true
	params.collide_with_bodies = false
	for result: Dictionary in get_world_3d().direct_space_state.intersect_shape(params, 4):
		# Crates share the enemy hurtbox layer; only real enemies trigger mines.
		var hb := result["collider"] as HurtBox
		if hb != null and hb.health != null and hb.health.get_parent() is Enemy:
			return true
	return false


func detonate() -> void:
	if is_queued_for_deletion():
		return
	Explosion.detonate(self, global_position, blast_radius, Layers.ENEMY_HURTBOX, _make_damage)
	GameFeel.impact(global_position, color, blast_radius * 2.0, 0.3)
	GameFeel.shake(0.25)
	queue_free()


func _make_damage() -> DamageInfo:
	var info: DamageInfo
	if is_instance_valid(weapon):
		info = weapon.make_damage(damage, global_position)
	else:
		info = DamageInfo.create(damage, global_position)
	info.knockback = knockback
	info.knockback_up = 6.0
	return info
