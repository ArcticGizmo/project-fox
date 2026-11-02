extends Weapon
## Brass Salamander: a short-range flame cone that ticks damage while held.
## From level 3 it sets enemies alight (burn damage over time).
## stats.max_range = cone length, stats.area_radius = cone end radius,
## stats.fire_interval = damage tick (and ammo use) interval.
## Signature (max level), stoked: holding the flame ramps its damage up to
## x (1 + stats.status_power) over stats.sub_interval seconds; the cone turns
## from orange to blue-white. Letting go resets it.

const STOKED_COLOR := Color(0.6, 0.8, 1.0)

const RING_POINTS := 12

var hit_box: HitBox
var _shape: CollisionShape3D
var _cone: MeshInstance3D
var _cone_mesh: CylinderMesh
var _active_left: float = 0.0
## 0..1: how far the flame is stoked (signature only).
var stoke: float = 0.0
var _cone_mat: StandardMaterial3D


func setup(p_data: WeaponData, p_wielder: Node3D) -> void:
	super(p_data, p_wielder)
	hit_box = HitBox.new()
	hit_box.name = "FlameHitBox"
	hit_box.collision_mask = Layers.ENEMY_HURTBOX
	hit_box.source_weapon = self
	hit_box.knockback = 1.0
	hit_box.knockback_up = 0.0
	_shape = CollisionShape3D.new()
	hit_box.add_child(_shape)
	add_child(hit_box)
	hit_box.hit_landed.connect(_on_hit_landed)
	hit_box.damage_modifier = func(_hb: HurtBox, info: DamageInfo) -> void: info.amount *= stoke_multiplier()

	_cone = MeshInstance3D.new()
	_cone_mesh = CylinderMesh.new()
	_cone.mesh = _cone_mesh
	_cone.rotation.x = -PI * 0.5  # cylinder +Y -> weapon forward (-Z)
	var mat := StandardMaterial3D.new()
	_cone_mat = mat
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(data.color, 0.45)
	_cone.material_override = mat
	_cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cone.visible = false
	add_child(_cone)
	_apply_stats()


func _physics_process(delta: float) -> void:
	super(delta)
	_active_left = maxf(0.0, _active_left - delta)


func _fire(_aim: AimInfo) -> void:
	# Each "shot" is one damage tick worth of ammo; keep the cone lit until the next.
	_active_left = stats().fire_interval * 1.5


func _trigger_update(held: bool, aim: AimInfo) -> void:
	if held and aim != null and aim.direction.length_squared() > 0.0001:
		var up := Vector3.UP if absf(aim.direction.y) < 0.99 else Vector3.RIGHT
		look_at(global_position + aim.direction, up)
	var on := held and _active_left > 0.0
	var s := stats()
	if on and s.signature and s.sub_interval > 0.0:
		stoke = minf(1.0, stoke + get_physics_process_delta_time() / s.sub_interval)
	elif not held:
		stoke = 0.0
	_cone_mat.albedo_color = Color(data.color.lerp(STOKED_COLOR, stoke), 0.45)
	hit_box.active = on
	_cone.visible = on
	if on:
		_cone.scale = Vector3.ONE * randf_range(0.9, 1.08)


func on_unequipped() -> void:
	super()
	_active_left = 0.0


func _on_level_changed() -> void:
	_apply_stats()


func _apply_stats() -> void:
	var s := stats()
	hit_box.damage = s.damage
	hit_box.repeat_interval = s.fire_interval
	var length := s.max_range
	var r := s.area_radius
	var pts := PackedVector3Array([Vector3.ZERO])
	for i: int in RING_POINTS:
		var a := TAU * float(i) / RING_POINTS
		pts.append(Vector3(cos(a) * r, sin(a) * r, -length))
	var convex := ConvexPolygonShape3D.new()
	convex.points = pts
	_shape.shape = convex
	_cone_mesh.top_radius = r
	_cone_mesh.bottom_radius = 0.08
	_cone_mesh.height = length
	_cone.position = Vector3(0, 0, -length * 0.5)
	hit_box.refresh_outline()


func _on_hit_landed(hb: HurtBox, _info: DamageInfo) -> void:
	var s := stats()
	if s.burn_dps <= 0.0 or hb.health == null:
		return
	var victim := hb.health.get_parent()
	if victim != null and victim.has_method(&"apply_burn"):
		victim.call(&"apply_burn", s.burn_dps, s.burn_duration, self)


## Damage multiplier from stoking (1 below max level).
func stoke_multiplier() -> float:
	return 1.0 + stats().status_power * stoke if stats().signature else 1.0
