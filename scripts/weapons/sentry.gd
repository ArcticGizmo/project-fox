class_name Sentry
extends Node3D
## A deployed clockwork tortoise turret. Shoots the nearest enemy in range
## (with line of sight) until its lifetime runs out. Reads its weapon's
## current stats every shot, so levelling up upgrades sentries already out.
## Enemies currently ignore sentries.

const SHELL_COLOR := Color(0.45, 0.65, 0.3)

var weapon: Weapon
var lifetime: float = 10.0
var target: Node3D = null
var shots_fired: int = 0

var _age: float = 0.0
var _cooldown: float = 0.3
var _head: Node3D
var _expiring: bool = false


func _ready() -> void:
	var shell := MeshInstance3D.new()
	var shell_mesh := BoxMesh.new()
	shell_mesh.size = Vector3(1.0, 0.5, 1.1)
	shell.mesh = shell_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SHELL_COLOR
	shell.material_override = mat
	shell.position.y = 0.25
	add_child(shell)
	var plate := MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(0.7, 0.15, 0.8)
	plate.mesh = plate_mesh
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.75, 0.6, 0.3)
	plate.material_override = brass
	plate.position.y = 0.55
	add_child(plate)

	_head = Node3D.new()
	_head.position = Vector3(0, 0.75, 0)
	add_child(_head)
	var barrel := MeshInstance3D.new()
	var barrel_mesh := BoxMesh.new()
	barrel_mesh.size = Vector3(0.18, 0.18, 0.6)
	barrel.mesh = barrel_mesh
	barrel.material_override = brass
	barrel.position.z = -0.3
	_head.add_child(barrel)

	scale = Vector3.ONE * 0.1
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	_age += delta
	if _expiring:
		return
	if _age >= lifetime or not is_instance_valid(weapon):
		expire()
		return
	var s := weapon.stats()
	target = _find_target(s.max_range)
	if target == null:
		return
	var aim := AimAssist.get_aim_point(target)
	_head.look_at(aim, Vector3.UP)
	_cooldown -= delta
	if _cooldown <= 0.0:
		_cooldown = s.sub_interval
		_shoot(aim, s)


func _find_target(max_range: float) -> Node3D:
	var best: Node3D = null
	var best_dist := max_range
	var from := _head.global_position
	var space := get_world_3d().direct_space_state
	for n: Node3D in AimAssist.nodes_in_group(get_tree(), &"enemies"):
		var p := AimAssist.get_aim_point(n)
		var d := from.distance_to(p)
		if d < best_dist and AimAssist.has_line_of_sight(space, from, p):
			best = n
			best_dist = d
	return best


func _shoot(aim_point: Vector3, s: WeaponLevelStats) -> void:
	var p := Projectile.new()
	p.direction = (aim_point - _head.global_position).normalized()
	p.speed = s.projectile_speed
	p.damage = s.damage
	p.lifetime = s.max_range / s.projectile_speed * 1.3
	p.radius = 0.2
	p.homing_deg_per_sec = s.homing_deg_per_sec
	p.homing_target = target
	p.hit_mask = Layers.WORLD | Layers.ENEMY_HURTBOX
	p.weapon = weapon
	p.color = Color(0.8, 1.0, 0.5)
	p.size = Vector3(0.12, 0.12, 0.3)
	get_parent().add_child(p)
	p.global_position = _head.global_position + p.direction * 0.6
	shots_fired += 1


func expire() -> void:
	if _expiring:
		return
	_expiring = true
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.05, 0.2)
	tw.tween_callback(queue_free)
