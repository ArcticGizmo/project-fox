class_name CoalEmber
extends Node3D
## A patch of live coals a Coal Beetle leaves behind (dropped as it crawls, or where a
## belched coal lands). Burns whoever stands in it: a DoT tick every `tick` seconds (no
## knockback, no i-frames). It is live from the moment it appears, so it always looks
## hot; it dims over the last FADE_TIME and goes out. Joins LobProjectile.GROUP so a
## respawn clears it.

const COLOR := Color(1.0, 0.38, 0.08)
const FADE_TIME := 1.0
const HEIGHT := 0.6
const LUMPS := 5

var radius: float = 1.0
var damage: float = 4.0
var tick: float = 0.5
var lifetime: float = 5.0
var hit_box: HitBox

var _age: float = 0.0
var _mat: StandardMaterial3D
var _lump_mat: StandardMaterial3D


static func spawn(parent: Node, at: Vector3, p_radius: float, p_damage: float, p_lifetime: float) -> CoalEmber:
	var e := CoalEmber.new()
	e.radius = p_radius
	e.damage = p_damage
	e.lifetime = p_lifetime
	parent.add_child(e)
	e.global_position = at
	return e


func _ready() -> void:
	add_to_group(LobProjectile.GROUP)
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.04
	disc.mesh = mesh
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(COLOR, 0.45)
	disc.material_override = _mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position.y = 0.03
	add_child(disc)

	_lump_mat = StandardMaterial3D.new()
	_lump_mat.albedo_color = Color(0.12, 0.08, 0.07)
	_lump_mat.emission_enabled = true
	_lump_mat.emission = COLOR * 1.5
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position)
	for i: int in LUMPS:
		var lump := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE * rng.randf_range(0.12, 0.22)
		lump.mesh = box
		lump.material_override = _lump_mat
		var a := TAU * float(i) / LUMPS + rng.randf_range(-0.4, 0.4)
		lump.position = Vector3(cos(a), 0.0, sin(a)) * radius * rng.randf_range(0.2, 0.7) + Vector3.UP * 0.06
		lump.rotation = Vector3(rng.randf(), rng.randf(), rng.randf()) * PI
		add_child(lump)

	hit_box = HitBox.new()
	hit_box.name = "EmberHitBox"
	hit_box.collision_mask = Layers.PLAYER_HURTBOX
	hit_box.damage = damage
	hit_box.knockback = 0.0
	hit_box.knockback_up = 0.0
	hit_box.repeat_interval = tick
	hit_box.damage_modifier = func(_hb: HurtBox, info: DamageInfo) -> void: info.is_dot = true
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = HEIGHT
	cs.shape = shape
	cs.position.y = HEIGHT * 0.5
	hit_box.add_child(cs)
	add_child(hit_box)
	hit_box.active = true


func _physics_process(delta: float) -> void:
	_age += delta
	var left := lifetime - _age
	var fade := clampf(left / FADE_TIME, 0.0, 1.0)
	var flicker := 0.85 + 0.15 * sin(_age * 9.0 + global_position.x)
	_mat.albedo_color.a = 0.45 * fade * flicker
	_lump_mat.emission = COLOR * 1.5 * fade * flicker
	if left <= 0.0:
		queue_free()
