class_name LobProjectile
extends Node3D
## Arcing glob with a ground marker showing exactly where and when it lands.
## Explodes on arrival, damaging hurtboxes on `hit_mask` within `radius`.

var start: Vector3 = Vector3.ZERO
var end: Vector3 = Vector3.ZERO
var flight_time: float = 1.0
var damage: float = 15.0
var radius: float = 2.0
var knockback: float = 9.0
var hit_mask: int = Layers.PLAYER_HURTBOX
var color: Color = Color(0.45, 0.9, 0.3)

var _t: float = 0.0
var _arc_height: float = 3.0
var _marker: MeshInstance3D
var _marker_mat: StandardMaterial3D


func _ready() -> void:
	_arc_height = 2.5 + start.distance_to(end) * 0.15
	global_position = start
	var glob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	glob.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.6
	glob.material_override = mat
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
	if u >= 1.0:
		_explode()


func _explode() -> void:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, end + Vector3.UP * 0.5)
	params.collision_mask = hit_mask
	params.collide_with_areas = true
	params.collide_with_bodies = false
	var hit_entities: Dictionary = {}
	for result: Dictionary in get_world_3d().direct_space_state.intersect_shape(params, 16):
		var hb := result["collider"] as HurtBox
		if hb == null or hit_entities.has(hb.entity_id()):
			continue
		hit_entities[hb.entity_id()] = true
		var info := DamageInfo.create(damage, end, knockback)
		info.knockback_up = 5.0
		hb.receive(info)
	DebugSettings.flash_sphere(end + Vector3.UP * 0.5, radius, Color(1, 0.2, 0.1), 0.35)
	GameFeel.impact(end + Vector3.UP * 0.3, color, radius * 2.0, 0.3)
	queue_free()
