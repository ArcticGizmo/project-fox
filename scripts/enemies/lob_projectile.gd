class_name LobProjectile
extends Node3D
## Arcing glob with a ground marker showing exactly where and when it lands.
## Explodes on arrival, damaging hurtboxes on `hit_mask` within `radius`.
## Passing through a REFLECTOR area (Hermit Bulwark) sends it back toward
## `source`, now hitting enemies and crediting the reflecting weapon.

const REFLECTED_COLOR := Color(1.0, 0.8, 0.3)
## Every enemy projectile in flight joins this group (LevelRoot clears it on reset).
const GROUP := &"enemy_projectiles"

var start: Vector3 = Vector3.ZERO
var end: Vector3 = Vector3.ZERO
var flight_time: float = 1.0
var damage: float = 15.0
var radius: float = 2.0
var knockback: float = 9.0
var hit_mask: int = Layers.PLAYER_HURTBOX
var color: Color = Color(0.45, 0.9, 0.3)
## Who threw it; reflected lobs fly back here.
var source: Node3D = null
var reflected: bool = false

var _t: float = 0.0
var _arc_height: float = 3.0
var _marker: MeshInstance3D
var _marker_mat: StandardMaterial3D
var _glob_mat: StandardMaterial3D
var _reflect_weapon: Weapon = null


## Throws a lob from `thrower` (its source, for reflection) into the thrower's parent.
static func launch(thrower: Node3D, from: Vector3, to: Vector3, time: float, lob_damage: float, lob_radius: float) -> LobProjectile:
	var lob := LobProjectile.new()
	lob.start = from
	lob.end = to
	lob.flight_time = time
	lob.damage = lob_damage
	lob.radius = lob_radius
	lob.source = thrower
	thrower.get_parent().add_child(lob)
	return lob


func _ready() -> void:
	add_to_group(GROUP)
	_arc_height = 2.5 + start.distance_to(end) * 0.15
	global_position = start
	var glob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	glob.mesh = sphere
	_glob_mat = StandardMaterial3D.new()
	_glob_mat.albedo_color = color
	_glob_mat.emission_enabled = true
	_glob_mat.emission = color * 0.6
	glob.material_override = _glob_mat
	add_child(glob)

	_marker = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.04
	_marker.mesh = disc
	_marker_mat = StandardMaterial3D.new()
	_marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker_mat.albedo_color = Color(1, 0.15, 0.1, 0.25)
	_marker.material_override = _marker_mat
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.top_level = true
	add_child(_marker)
	_marker.global_position = end + Vector3.UP * 0.03


func position_at(u: float) -> Vector3:
	return start.lerp(end, u) + Vector3.UP * 4.0 * _arc_height * u * (1.0 - u)


func _physics_process(delta: float) -> void:
	_t += delta
	var u := clampf(_t / flight_time, 0.0, 1.0)
	global_position = position_at(u)
	# Marker brightens and pulses faster as impact approaches.
	_marker_mat.albedo_color.a = 0.2 + 0.45 * u + 0.1 * sin(_t * (8.0 + 20.0 * u))
	if not reflected:
		_check_reflector()
	if u >= 1.0:
		_explode()


func _check_reflector() -> void:
	var params := PhysicsPointQueryParameters3D.new()
	params.position = global_position
	params.collision_mask = Layers.REFLECTOR
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var hits := get_world_3d().direct_space_state.intersect_point(params, 1)
	if hits.is_empty():
		return
	var wall := (hits[0]["collider"] as Node).get_parent()
	reflect(float(wall.get(&"reflect_damage")), wall.get(&"weapon") as Weapon)


## Send the lob back toward its thrower as a player-side attack.
func reflect(new_damage: float, weapon: Weapon) -> void:
	reflected = true
	_reflect_weapon = weapon
	damage = new_damage
	hit_mask = Layers.ENEMY_HURTBOX
	var back: Vector3
	if source != null and is_instance_valid(source):
		back = source.global_position
	else:
		var d := start - end
		d.y = 0.0
		back = global_position + d.normalized() * 8.0
	start = global_position
	end = back
	_t = 0.0
	var dist := start.distance_to(end)
	flight_time = clampf(dist / 14.0, 0.4, 0.9)
	_arc_height = 1.0 + dist * 0.08
	_glob_mat.albedo_color = REFLECTED_COLOR
	_glob_mat.emission = REFLECTED_COLOR * 0.8
	_marker_mat.albedo_color = Color(1, 0.8, 0.3, 0.25)
	_marker.global_position = end + Vector3.UP * 0.03
	GameFeel.impact(global_position, REFLECTED_COLOR, 1.2, 0.15)


func _explode() -> void:
	Explosion.detonate(self, end + Vector3.UP * 0.5, radius, hit_mask, _make_damage)
	GameFeel.impact(end + Vector3.UP * 0.3, color, radius * 2.0, 0.3)
	queue_free()


func _make_damage() -> DamageInfo:
	var info: DamageInfo
	if reflected and is_instance_valid(_reflect_weapon):
		info = _reflect_weapon.make_damage(damage, end)
		info.knockback = knockback
	else:
		info = DamageInfo.create(damage, end, knockback)
	info.knockback_up = 5.0
	return info
