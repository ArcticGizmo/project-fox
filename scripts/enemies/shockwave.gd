class_name Shockwave
extends Node3D
## Expanding ground ring (Furnace Stag stomp). The ring is `width` thick and
## `height` tall from the ground it started on: anything on `hit_mask` whose feet
## are inside the band and below the top is hit once, so a jump clears it.
## Not a HitBox (an annulus is not a convex shape), but damage still flows
## through HurtBox.receive() with one DamageInfo per hit.

const COLOR := Color(1.0, 0.55, 0.2)

var speed: float = 9.0
var max_radius: float = 16.0
var width: float = 0.6
var height: float = 0.7
var damage: float = 18.0
var knockback: float = 8.0
var hit_mask: int = Layers.PLAYER_HURTBOX
var radius: float = 0.0
## Entities hit so far (tests).
var hit_count: int = 0

var _hit: Dictionary = {}
var _ring: MeshInstance3D
var _mesh: TorusMesh
var _mat: StandardMaterial3D
var _shape: CylinderShape3D


static func spawn(parent: Node, at: Vector3) -> Shockwave:
	var s := Shockwave.new()
	parent.add_child(s)
	s.global_position = at
	return s


func _ready() -> void:
	add_to_group(LobProjectile.GROUP)
	_ring = MeshInstance3D.new()
	_mesh = TorusMesh.new()
	_mesh.rings = 48
	_ring.mesh = _mesh
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(COLOR, 0.8)
	_ring.material_override = _mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_shape = CylinderShape3D.new()
	_shape.height = height + 2.0
	_update_mesh()


func _physics_process(delta: float) -> void:
	radius += speed * delta
	if radius > max_radius:
		queue_free()
		return
	_update_mesh()
	_check_hits()


func _update_mesh() -> void:
	var r := maxf(radius, width * 0.5 + 0.01)
	_mesh.inner_radius = maxf(0.01, r - width * 0.5)
	_mesh.outer_radius = r + width * 0.5
	# Squash the torus so it reads as a low wall of force.
	_ring.scale = Vector3(1.0, height / width, 1.0)
	_ring.position.y = height * 0.5
	_mat.albedo_color.a = 0.85 * (1.0 - 0.6 * radius / max_radius)


## Whether a point at `feet` (ground level of the target) is inside the band.
func catches(feet: Vector3) -> bool:
	var flat := Vector2(feet.x - global_position.x, feet.z - global_position.z).length()
	var up := feet.y - global_position.y
	return absf(flat - radius) <= width * 0.5 + 0.35 and up < height


func _check_hits() -> void:
	_shape.radius = radius + width
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _shape
	params.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * height * 0.5)
	params.collision_mask = hit_mask
	params.collide_with_areas = true
	params.collide_with_bodies = false
	for r: Dictionary in get_world_3d().direct_space_state.intersect_shape(params, 16):
		var hb := r["collider"] as HurtBox
		if hb == null or _hit.has(hb.entity_id()):
			continue
		var owner_body := hb.get_parent() as Node3D
		var feet := owner_body.global_position if owner_body != null else hb.global_position
		if not catches(feet):
			continue
		var info := DamageInfo.create(damage, global_position, knockback)
		info.knockback_up = 6.0
		if hb.receive(info):
			_hit[hb.entity_id()] = true
			hit_count += 1
