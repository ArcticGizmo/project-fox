class_name LeafCloak
extends Node3D
## Leaf-wing Cloak (gadget &"glide"). A component on the player, like
## GrappleTail: the player decides when it opens (`open()` / `close()`, see
## Player._update_glide) and, while `is_open()`, uses `glide_velocity()` instead
## of normal air movement. It owns the two leaf wings that unfold on the fox's
## back. Feel numbers: the "Glide" group of PlayerTuning.

signal opened
signal closed

const LEAF_COLOR := Color(0.38, 0.7, 0.3)
const VEIN_COLOR := Color(0.2, 0.42, 0.16)
## Wing root on the fox's back, in the player's visual space.
const WING_ROOT := Vector3(0, 1.35, 0.25)

var player: Player
var tuning: PlayerTuning
## Horizontal travel direction while open (steered toward the stick).
var heading: Vector3 = Vector3.FORWARD
## 0 = folded, 1 = fully unfolded (visual only).
var unfold: float = 0.0

var _open: bool = false
var _wings: Array[Node3D] = []


func _ready() -> void:
	name = "LeafCloak"
	position = WING_ROOT
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = LEAF_COLOR
	leaf.emission_enabled = true
	leaf.emission = LEAF_COLOR * 0.15
	leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	var vein := StandardMaterial3D.new()
	vein.albedo_color = VEIN_COLOR
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "WingL" if side < 0.0 else "WingR"
		add_child(pivot)
		# A long flat leaf hanging out sideways from the pivot, a darker vein down its middle.
		_box(pivot, Vector3(1.5, 0.05, 0.7), Vector3(side * 0.8, 0, 0.05), leaf)
		_box(pivot, Vector3(1.0, 0.04, 0.45), Vector3(side * 1.6, 0, 0.15), leaf)
		_box(pivot, Vector3(1.9, 0.07, 0.07), Vector3(side * 1.05, 0.02, 0.05), vein)
		_wings.append(pivot)
	_apply_pose()


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


func is_open() -> bool:
	return _open


func open() -> void:
	if _open:
		return
	_open = true
	var h := Vector3(player.velocity.x, 0.0, player.velocity.z)
	heading = h.normalized() if h.length() > 0.5 else player.facing_forward()
	opened.emit()


func close() -> void:
	if not _open:
		return
	_open = false
	closed.emit()


## Velocity for one gliding frame. `wish` = camera-relative stick, `lift` =
## the strongest SteamVent updraft at the fox (0..1).
func glide_velocity(delta: float, wish: Vector3, lift: float) -> Vector3:
	if wish.length_squared() > 0.01:
		var target := wish.normalized()
		var angle := heading.signed_angle_to(target, Vector3.UP)
		var step := deg_to_rad(tuning.glide_turn_speed_deg) * delta
		heading = heading.rotated(Vector3.UP, clampf(angle, -step, step)).normalized()
	var h := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var target_speed := lerpf(tuning.glide_idle_speed, tuning.glide_speed, clampf(wish.length(), 0.0, 1.0))
	var speed := move_toward(h.dot(heading), target_speed, tuning.glide_acceleration * delta)
	var target_vy := lerpf(-tuning.glide_fall_speed, tuning.glide_vent_rise_speed, clampf(lift, 0.0, 1.0))
	var vy := move_toward(player.velocity.y, target_vy, tuning.glide_vertical_acceleration * delta)
	return heading * maxf(speed, 0.0) + Vector3.UP * vy


## Unfold / fold the wings (call every frame).
func update_visual(delta: float) -> void:
	unfold = move_toward(unfold, 1.0 if _open else 0.0, delta / maxf(tuning.glide_unfold_time, 0.01))
	_apply_pose()


func _apply_pose() -> void:
	var t := unfold * unfold * (3.0 - 2.0 * unfold)  # smoothstep
	visible = t > 0.02
	for i: int in _wings.size():
		var side := -1.0 if i == 0 else 1.0
		var w := _wings[i]
		# Folded: hanging down the back. Open: spread out with a slight dihedral.
		w.scale = Vector3(lerpf(0.15, 1.0, t), 1.0, 1.0)
		w.rotation = Vector3(0.0, 0.0, side * lerpf(-1.35, 0.18, t))
