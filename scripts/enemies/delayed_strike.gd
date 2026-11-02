class_name DelayedStrike
extends Node3D
## A marked spot that strikes after `delay` (Furnace Stag antler lightning).
## The disc brightens and pulses faster toward the strike, then an
## Explosion.detonate() on `hit_mask` and a bolt flash. Joins the enemy
## projectile group so level resets clear it.

const COLOR := Color(0.6, 0.85, 1.0)

var delay: float = 0.9
var radius: float = 2.2
var damage: float = 20.0
var hit_mask: int = Layers.PLAYER_HURTBOX
var struck: bool = false

var _t: float = 0.0
var _mat: StandardMaterial3D


static func spawn(parent: Node, at: Vector3, p_delay: float, p_radius: float, p_damage: float) -> DelayedStrike:
	var s := DelayedStrike.new()
	s.delay = p_delay
	s.radius = p_radius
	s.damage = p_damage
	parent.add_child(s)
	s.global_position = at
	return s


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
	_mat.albedo_color = Color(COLOR, 0.2)
	disc.material_override = _mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position.y = 0.04
	add_child(disc)


func _physics_process(delta: float) -> void:
	_t += delta
	var u := clampf(_t / delay, 0.0, 1.0)
	_mat.albedo_color.a = 0.15 + 0.5 * u + 0.1 * sin(_t * (8.0 + 24.0 * u))
	if _t >= delay and not struck:
		_strike()


func _strike() -> void:
	struck = true
	var centre := global_position + Vector3.UP * 0.6
	Explosion.detonate(self, centre, radius, hit_mask, func() -> DamageInfo:
		var info := DamageInfo.create(damage, centre, 7.0)
		info.knockback_up = 5.0
		return info)
	GameFeel.impact(centre, COLOR, radius * 2.0, 0.25)
	_bolt()
	Sfx.play(&"shot_zap", centre, 6.0)
	queue_free()


## A short vertical flash for the bolt (outlives this node).
func _bolt() -> void:
	var bolt := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.25, 12.0, 0.25)
	bolt.mesh = box
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.9)
	bolt.material_override = mat
	get_parent().add_child(bolt)
	bolt.global_position = global_position + Vector3.UP * 6.0
	var tw := bolt.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.2)
	tw.tween_callback(bolt.queue_free)
