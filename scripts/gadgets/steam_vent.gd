@tool
class_name SteamVent
extends Node3D
## A steam vent: an updraft column above this node (its origin is the vent
## mouth). A gliding fox (LeafCloak open) is lifted toward the top of the column;
## a fox that is not gliding gets only a small upward push. Never damaging (the
## steam hammer is the hazard). The player asks `SteamVent.lift_at()` each frame.

const GROUP := &"steam_vents"
const STEAM_COLOR := Color(0.9, 0.95, 0.92)

## Column radius (horizontal) around the vent mouth.
@export var radius: float = 1.6:
	set(value):
		radius = value
		_rebuild()
## Column height above the mouth. Lift is full up to `full_fraction` of it and
## fades to zero at the top, so a glider settles near the top.
@export var lift_height: float = 7.0:
	set(value):
		lift_height = value
		_rebuild()
@export_range(0.0, 1.0) var full_fraction: float = 0.6

var _plume: Node3D


func _ready() -> void:
	add_to_group(GROUP)
	_rebuild()


## Updraft strength at a world position: 0 outside the column, 1 in its lower part.
func lift_at(pos: Vector3) -> float:
	var local := pos - global_position
	var up := local.y
	if up < -0.5 or up > lift_height:
		return 0.0
	if Vector2(local.x, local.z).length() > radius:
		return 0.0
	var fade_from := lift_height * full_fraction
	if up <= fade_from:
		return 1.0
	return clampf((lift_height - up) / maxf(lift_height - fade_from, 0.01), 0.0, 1.0)


## Strongest updraft from any vent at `pos`.
static func lift_in(tree: SceneTree, pos: Vector3) -> float:
	var best := 0.0
	for n: Node in tree.get_nodes_in_group(GROUP):
		var v := n as SteamVent
		if v != null:
			best = maxf(best, v.lift_at(pos))
	return best


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _plume != null:
		_plume.queue_free()
	_plume = Node3D.new()
	_plume.name = "Plume"
	add_child(_plume)
	# Stacked translucent cones that widen and fade with height, plus drifting puffs.
	var layers := 4
	for i: int in layers:
		var f := float(i) / layers
		var cyl := CylinderMesh.new()
		cyl.bottom_radius = lerpf(radius * 0.35, radius * 0.8, f)
		cyl.top_radius = lerpf(radius * 0.5, radius, f + 1.0 / layers)
		cyl.height = lift_height / layers
		cyl.cap_top = false
		cyl.cap_bottom = false
		var mi := MeshInstance3D.new()
		mi.mesh = cyl
		mi.position.y = lift_height * (f + 0.5 / layers)
		mi.material_override = _steam_material(lerpf(0.16, 0.05, f))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_plume.add_child(mi)
	var puffs := GPUParticles3D.new()
	puffs.name = "Puffs"
	puffs.amount = 24
	puffs.lifetime = 1.6
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radius * 0.4
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = lift_height / 1.6 * 0.8
	pm.initial_velocity_max = lift_height / 1.6 * 1.1
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	puffs.process_material = pm
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	sphere.radial_segments = 8
	sphere.rings = 4
	sphere.material = _steam_material(0.22)
	puffs.draw_pass_1 = sphere
	puffs.visibility_aabb = AABB(Vector3(-radius, -1, -radius), Vector3(radius * 2, lift_height + 2, radius * 2))
	_plume.add_child(puffs)


func _steam_material(alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(STEAM_COLOR, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
