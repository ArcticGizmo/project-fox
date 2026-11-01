class_name BurrowClaws
extends Node3D
## Burrow Claws (gadget &"burrow"). A component on the player, like GrappleTail:
## the player decides when to dig in (a floor dodge on a SoilPatch), tunnel
## (dodge on a linked patch) and pop out (jump, or dodge on a standalone patch),
## see Player._move_burrowed. While `is_active()` the fox is underground: its
## visual sinks and hides, a dirt mound shows where it is, it is hidden from
## enemy perception and takes no damage. This node owns the phases, the
## underground movement (confined to the patch) and the mound.
##
## Feel numbers: the "Burrow" group of PlayerTuning.

signal dived(patch: SoilPatch)
signal tunnelled(from: SoilPatch, to: SoilPatch)
signal surfaced(patch: SoilPatch)

enum Phase { IDLE, DIVE, UNDER, TUNNEL }

## Fresh, lighter earth than a SoilPatch, so the moving mound reads on it.
const MOUND_COLOR := Color(0.62, 0.45, 0.27)
## Underground movement stays this far inside the patch edge.
const EDGE_MARGIN := 0.35
## Mound dips this far below the surface halfway along a tunnel (it passes under walls).
const TUNNEL_DEPTH := 0.6

var player: Player
var tuning: PlayerTuning
var phase: Phase = Phase.IDLE
var phase_time: float = 0.0
## The patch the fox is under (the destination while tunnelling).
var patch: SoilPatch

var _tunnel_from: Vector3
var _tunnel_to: Vector3
var _tunnel_time: float = 0.0
var _mound: Node3D
var _clods: Array[Node3D] = []


func _ready() -> void:
	name = "BurrowClaws"
	_mound = Node3D.new()
	_mound.name = "DirtMound"
	_mound.top_level = true
	_mound.visible = false
	add_child(_mound)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = MOUND_COLOR
	mat.roughness = 1.0
	var dark := StandardMaterial3D.new()
	dark.albedo_color = MOUND_COLOR.darkened(0.3)
	dark.roughness = 1.0
	var hump := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.7
	sphere.height = 0.7
	hump.mesh = sphere
	hump.material_override = mat
	_mound.add_child(hump)
	# Clods tumbling round the hump so a moving mound reads as digging.
	for i: int in 5:
		var pivot := Node3D.new()
		pivot.rotation.y = TAU * float(i) / 5.0
		_mound.add_child(pivot)
		var clod := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE * (0.14 + 0.04 * float(i % 2))
		clod.mesh = box
		clod.material_override = dark
		clod.position = Vector3(0.55, 0.12, 0)
		pivot.add_child(clod)
		_clods.append(pivot)


func is_active() -> bool:
	return phase != Phase.IDLE


func is_under() -> bool:
	return phase == Phase.UNDER


## Dig into `p` (the player checked the gadget and the floor dodge).
func start(p: SoilPatch) -> void:
	patch = p
	phase = Phase.DIVE
	phase_time = 0.0
	_puff()
	dived.emit(p)


## Travel to the linked patch. Returns false on a standalone patch.
func start_tunnel() -> bool:
	if phase != Phase.UNDER or patch == null:
		return false
	var to := patch.partner()
	if to == null:
		return false
	var from := patch
	_tunnel_from = player.global_position
	_tunnel_to = to.global_position + Vector3.UP * 0.05
	_tunnel_time = maxf(tuning.burrow_tunnel_min_time, _tunnel_from.distance_to(_tunnel_to) / maxf(tuning.burrow_tunnel_speed, 0.1))
	patch = to
	phase = Phase.TUNNEL
	phase_time = 0.0
	tunnelled.emit(from, to)
	return true


## Back to the surface (the player gives the hop).
func surface() -> void:
	if not is_active():
		return
	var p := patch
	phase = Phase.IDLE
	phase_time = 0.0
	_mound.visible = false
	_puff()
	surfaced.emit(p)


## Drop out without ceremony (death, respawn, launch).
func cancel() -> void:
	phase = Phase.IDLE
	phase_time = 0.0
	_mound.visible = false


## Advance the phase clock; DIVE turns into UNDER after burrow_dive_time.
func tick(delta: float) -> void:
	phase_time += delta
	if phase == Phase.DIVE and phase_time >= tuning.burrow_dive_time:
		phase = Phase.UNDER
		phase_time = 0.0


## Horizontal velocity while diving or under the patch. `wish` = camera-relative stick.
func move_velocity(delta: float, wish: Vector3) -> Vector3:
	var h := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var target := Vector3.ZERO if phase == Phase.DIVE else wish * tuning.burrow_move_speed
	return h.move_toward(target, tuning.burrow_acceleration * delta)


## Keep the fox inside its patch (call after moving).
func confine() -> void:
	if patch == null or not is_instance_valid(patch):
		return
	var pos := player.global_position
	var kept := patch.confine(pos, EDGE_MARGIN)
	if kept != pos:
		player.global_position = kept
		# Drop the outward part of the velocity so the mound slides along the edge.
		var out := Vector3(pos.x - kept.x, 0.0, pos.z - kept.z).normalized()
		var v := player.velocity
		var along := v.dot(out)
		if along > 0.0:
			player.velocity = v - out * along


## Position along the tunnel this frame; true once arrived (now UNDER the partner).
func tunnel_position() -> Vector3:
	var t := clampf(phase_time / maxf(_tunnel_time, 0.01), 0.0, 1.0)
	if t >= 1.0:
		phase = Phase.UNDER
		phase_time = 0.0
	var s := t * t * (3.0 - 2.0 * t)
	return _tunnel_from.lerp(_tunnel_to, s)


## 0 = fox at the surface, 1 = fully sunk (visual).
func sink() -> float:
	match phase:
		Phase.DIVE:
			return clampf(phase_time / maxf(tuning.burrow_dive_time, 0.01), 0.0, 1.0)
		Phase.UNDER, Phase.TUNNEL:
			return 1.0
	return 0.0


## Mound follows the fox, swells as it dives, wobbles while moving, dips mid-tunnel.
func update_visual(delta: float) -> void:
	if not is_active():
		_mound.visible = false
		return
	_mound.visible = true
	var depth := 0.0
	if phase == Phase.TUNNEL:
		depth = sin(clampf(phase_time / maxf(_tunnel_time, 0.01), 0.0, 1.0) * PI) * TUNNEL_DEPTH
	var speed := Vector3(player.velocity.x, 0.0, player.velocity.z).length()
	if phase == Phase.TUNNEL:
		speed = tuning.burrow_tunnel_speed
	var grow := sink()
	var wobble := sin(Time.get_ticks_msec() * 0.02) * 0.06 * clampf(speed / 3.0, 0.0, 1.0)
	_mound.global_position = player.global_position + Vector3.UP * (-0.08 - depth + wobble)
	_mound.scale = Vector3(lerpf(0.3, 1.0, grow), lerpf(0.2, 1.0, grow) + wobble, lerpf(0.3, 1.0, grow))
	for c: Node3D in _clods:
		c.rotation.y += delta * (1.5 + speed * 1.2)


func _puff() -> void:
	if player != null and player.is_inside_tree():
		GameFeel.impact(player.global_position + Vector3.UP * 0.2, Color(0.45, 0.3, 0.16, 0.8), 1.8, 0.3)
