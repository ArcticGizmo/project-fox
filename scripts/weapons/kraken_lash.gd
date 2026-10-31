extends Weapon
## Kraken Lash: a whip crack along the aim line that hits everything on it.
## The tip (last TIP_FRACTION of the length) is a sweet spot that deals
## stats.crit_multiplier damage. Negative stats.knockback pulls enemies in
## (used from level 3).
## stats.max_range = lash length, stats.area_radius = lash thickness.

const WINDUP := 0.06
const ACTIVE := 0.1
const LINGER := 0.1
const TIP_FRACTION := 0.25

var hit_box: HitBox
var _shape: BoxShape3D
var _cs: CollisionShape3D
var _lash: MeshInstance3D
var _lash_mesh: BoxMesh
var _timer: float = -1.0
var _dir: Vector3 = Vector3.FORWARD


func setup(p_data: WeaponData, p_wielder: Node3D) -> void:
	super(p_data, p_wielder)
	hit_box = HitBox.new()
	hit_box.name = "LashHitBox"
	hit_box.collision_mask = Layers.ENEMY_HURTBOX
	hit_box.source_weapon = self
	hit_box.damage_modifier = _apply_tip_bonus
	_shape = BoxShape3D.new()
	_cs = CollisionShape3D.new()
	_cs.shape = _shape
	hit_box.add_child(_cs)
	add_child(hit_box)

	_lash = MeshInstance3D.new()
	_lash_mesh = BoxMesh.new()
	_lash.mesh = _lash_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = data.color
	mat.emission_enabled = true
	mat.emission = data.color * 0.4
	_lash.material_override = mat
	_lash.visible = false
	add_child(_lash)
	_apply_stats()


func _physics_process(delta: float) -> void:
	super(delta)
	if _timer < 0.0:
		return
	_timer += delta
	_orient()
	hit_box.active = _timer >= WINDUP and _timer < WINDUP + ACTIVE
	var extend := clampf(_timer / (WINDUP + ACTIVE * 0.5), 0.0, 1.0)
	var length := stats().max_range * extend
	_lash_mesh.size = Vector3(0.12, 0.12, maxf(0.01, length))
	_lash.position = Vector3(0, 0, -length * 0.5)
	if _timer >= WINDUP + ACTIVE + LINGER:
		_timer = -1.0
		_lash.visible = false
		hit_box.active = false


func _fire(aim: AimInfo) -> void:
	_dir = aim.direction
	_timer = 0.0
	_lash.visible = true
	hit_box.active = false
	_orient()


func on_unequipped() -> void:
	super()
	_timer = -1.0
	_lash.visible = false
	hit_box.active = false


func _orient() -> void:
	if _dir.length_squared() > 0.0001 and is_inside_tree():
		look_at(global_position + _dir, Vector3.UP if absf(_dir.y) < 0.99 else Vector3.RIGHT)


func _on_level_changed() -> void:
	_apply_stats()


func _apply_stats() -> void:
	var s := stats()
	var width := maxf(0.5, s.area_radius)
	_shape.size = Vector3(width, width, s.max_range)
	_cs.position = Vector3(0, 0, -s.max_range * 0.5)
	hit_box.damage = s.damage
	hit_box.knockback = s.knockback
	hit_box.knockback_up = 1.5 if s.knockback >= 0.0 else 0.5
	hit_box.refresh_outline()


## Distance along the lash (0 at the fox, 1 at the tip) of a hurtbox.
func lash_fraction(hb: HurtBox) -> float:
	return clampf(-to_local(hb.center()).z / stats().max_range, 0.0, 1.0)


func _apply_tip_bonus(hb: HurtBox, info: DamageInfo) -> void:
	if lash_fraction(hb) >= 1.0 - TIP_FRACTION:
		info.amount *= stats().crit_multiplier
		info.is_critical = true
