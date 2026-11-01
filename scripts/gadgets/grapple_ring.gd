@tool
class_name GrappleRing
extends Node3D
## A brass ring the Grapple-Tail reels the fox to (see GrappleTail). Place one
## anywhere, ideally 1-2 m above the ledge it should land you on; the grapple
## GadgetGate builds one on top of itself. The ring's origin is the anchor.
##
## If the ring is mounted under a CollisionObject3D (a Block or gate), that body
## does not block line of sight to its own ring, so a ring on a ledge top can be
## targeted from below the lip.

const GROUP := &"grapple_rings"
const COLOR := Color(0.78, 0.6, 0.25)
const HIGHLIGHT_COLOR := Color(1.0, 0.85, 0.35)

enum Highlight { NONE, IN_REACH, READY }

## Draw the short post under the ring (off for rings hung from ceilings).
@export var show_post: bool = true

var highlight: Highlight = Highlight.NONE
## The body this ring is mounted on (nearest CollisionObject3D ancestor), or null.
var mount: CollisionObject3D

var _halo: MeshInstance3D
var _halo_material: StandardMaterial3D
var _pip: MeshInstance3D
var _time: float = 0.0


func _ready() -> void:
	var p := get_parent()
	while p != null and not (p is CollisionObject3D):
		p = p.get_parent()
	mount = p as CollisionObject3D
	_build()
	if not Engine.is_editor_hint():
		add_to_group(GROUP)


func is_available() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and is_visible_in_tree()


func set_highlight(value: Highlight) -> void:
	if value == highlight:
		return
	highlight = value
	if _halo != null:
		_halo.visible = value != Highlight.NONE
		_pip.visible = value == Highlight.READY


func _process(delta: float) -> void:
	if _halo == null or highlight == Highlight.NONE:
		return
	_time += delta
	var live := highlight == Highlight.READY
	var pulse := 0.5 + 0.5 * sin(_time * (10.0 if live else 4.0))
	_halo.scale = Vector3.ONE * (1.0 + (0.12 if live else 0.05) * pulse)
	_halo_material.albedo_color = Color(HIGHLIGHT_COLOR, 0.9 if live else 0.35)
	_halo_material.emission = HIGHLIGHT_COLOR * ((1.6 + pulse) if live else 0.5)
	_pip.position.y = 0.95 + 0.12 * pulse


func _build() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.45
	ring.outer_radius = 0.6
	var r := _mesh(ring, COLOR.lightened(0.25), 0.6)
	r.rotation.x = PI * 0.5
	if show_post:
		var post := CylinderMesh.new()
		post.top_radius = 0.06
		post.bottom_radius = 0.06
		post.height = 0.8
		_mesh(post, COLOR.darkened(0.3)).position.y = -1.0

	# Highlight: a bright halo around the ring and a pip above it when jump grapples.
	var halo := TorusMesh.new()
	halo.inner_radius = 0.66
	halo.outer_radius = 0.8
	_halo = _mesh(halo, HIGHLIGHT_COLOR, 2.0)
	_halo.rotation.x = PI * 0.5
	_halo_material = _halo.material_override as StandardMaterial3D
	_halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var pip := CylinderMesh.new()  # a cone pointing down at the ring
	pip.top_radius = 0.18
	pip.bottom_radius = 0.0
	pip.height = 0.35
	_pip = _mesh(pip, HIGHLIGHT_COLOR, 2.0)
	_pip.position.y = 0.95
	_halo.visible = false
	_pip.visible = false


func _mesh(mesh: Mesh, c: Color, glow: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.5
	mat.metallic = 0.4
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = Color(c.r, c.g, c.b) * glow
	mi.material_override = mat
	add_child(mi)
	return mi
