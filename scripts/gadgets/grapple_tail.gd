class_name GrappleTail
extends Node3D
## Brass Grapple-Tail (gadget &"grapple"). A component on the player, like
## StaffMelee: it picks and highlights the best GrappleRing, throws the tail,
## computes the reel velocity and draws the rope. The player owns the body:
## it asks `update_target()` every frame, calls `start()` when jump is pressed
## in the air with a ring ready, and while `is_active()` uses `reel()` as its
## velocity instead of normal movement.
##
## Feel numbers: the "Grapple" group of PlayerTuning.

signal started(ring: GrappleRing)
signal arrived(ring: GrappleRing)
signal cancelled

enum Phase { IDLE, THROW, REEL }

const ROPE_COLOR := Color(0.85, 0.66, 0.3)
## Where the rope leaves the fox: the tail tip, in the player's visual space.
const TAIL_TIP := Vector3(0, 0.75, 0.95)

var player: Player
var tuning: PlayerTuning
var phase: Phase = Phase.IDLE
var phase_time: float = 0.0
## Best ring this frame (null when locked, none in reach or none visible).
var target: GrappleRing
## Ring being reeled to while active.
var ring: GrappleRing
## True for the one frame reel() returned the release hop.
var just_released: bool = false

var _speed: float = 0.0
var _rope: MeshInstance3D


func _ready() -> void:
	name = "GrappleTail"
	_rope = MeshInstance3D.new()
	_rope.name = "Rope"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.035
	cyl.height = 1.0
	cyl.radial_segments = 6
	cyl.rings = 1
	_rope.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ROPE_COLOR
	mat.emission_enabled = true
	mat.emission = ROPE_COLOR * 0.6
	_rope.material_override = mat
	_rope.top_level = true
	_rope.visible = false
	add_child(_rope)


func is_active() -> bool:
	return phase != Phase.IDLE


## A ring is highlighted and jump would grapple to it (airborne).
func is_ready() -> bool:
	return target != null and phase == Phase.IDLE and not player.is_on_floor()


## Point on the fox that is reeled to the ring.
func hang_point() -> Vector3:
	return player.global_position + Vector3.UP * tuning.grapple_hang_height


## Pick the best ring and set ring highlights. `enabled` = gadget owned.
func update_target(enabled: bool) -> void:
	var best: GrappleRing = null
	if is_active():
		best = ring
	elif enabled and not player.is_dead:
		best = _pick_ring()
	if target != null and target != best and is_instance_valid(target):
		target.set_highlight(GrappleRing.Highlight.NONE)
	target = best
	if target != null:
		var live := is_active() or not player.is_on_floor()
		target.set_highlight(GrappleRing.Highlight.READY if live else GrappleRing.Highlight.IN_REACH)


func _pick_ring() -> GrappleRing:
	var hang := hang_point()
	var forward := player.camera_forward()
	var best: GrappleRing = null
	var best_score := INF
	for n: Node in get_tree().get_nodes_in_group(GrappleRing.GROUP):
		var r := n as GrappleRing
		if r == null or not r.is_available():
			continue
		var to := r.global_position - hang
		var dist := to.length()
		if dist > tuning.grapple_range or dist < tuning.grapple_min_distance:
			continue
		if r.global_position.y < player.global_position.y - tuning.grapple_max_drop:
			continue
		var flat := Vector3(to.x, 0.0, to.z)
		var angle := 0.0
		if flat.length() > 1.0:
			angle = rad_to_deg(forward.angle_to(flat.normalized()))
		if angle > tuning.grapple_aim_cone_deg:
			continue
		var score := angle / tuning.grapple_aim_cone_deg + dist / tuning.grapple_range
		if score < best_score and has_line_of_sight(r):
			best = r
			best_score = score
	return best


## Clear line from the fox's reel point to the ring (the ring's own mount ignored).
func has_line_of_sight(r: GrappleRing) -> bool:
	var q := PhysicsRayQueryParameters3D.create(hang_point(), r.global_position, Layers.WORLD)
	var exclude: Array[RID] = [player.get_rid()]
	if r.mount != null:
		exclude.append(r.mount.get_rid())
	q.exclude = exclude
	return player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Throw the tail at the highlighted ring. Returns false if there is none.
func start() -> bool:
	if target == null or is_active():
		return false
	ring = target
	phase = Phase.THROW
	phase_time = 0.0
	just_released = false
	started.emit(ring)
	return true


func cancel() -> void:
	if not is_active():
		return
	phase = Phase.IDLE
	ring = null
	_rope.visible = false
	cancelled.emit()


## Velocity for this frame while active. On arrival returns the release hop,
## sets `just_released` and goes idle.
func reel(delta: float) -> Vector3:
	just_released = false
	phase_time += delta
	if not is_instance_valid(ring) or not ring.is_available():
		cancel()
		return player.velocity
	var to := ring.global_position - hang_point()
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	if phase == Phase.THROW:
		if phase_time < tuning.grapple_throw_time:
			return player.velocity * exp(-12.0 * delta)  # hang while the tail flies
		phase = Phase.REEL
		phase_time = 0.0
		_speed = maxf(tuning.grapple_reel_start_speed, player.velocity.dot(dir))
	if phase_time > tuning.grapple_max_time:
		cancel()
		return player.velocity
	_speed = move_toward(_speed, tuning.grapple_reel_speed, tuning.grapple_reel_acceleration * delta)
	var ease_t := clampf(dist / tuning.grapple_ease_distance, 0.0, 1.0)
	var speed := minf(_speed, lerpf(tuning.grapple_arrive_speed, tuning.grapple_reel_speed, ease_t))
	if dist <= tuning.grapple_release_distance or speed * delta >= dist:
		return _release(dir)
	# Pulled into a wall (the ledge's lip): slide along it at full speed, so the
	# fox climbs the face and goes over the top instead of stalling.
	if player.is_on_wall():
		var n := player.get_wall_normal()
		var into := dir.dot(n)
		if into < 0.0:
			var slid := dir - n * into
			if slid.length() > 0.05:
				dir = slid.normalized()
	return dir * speed


func _release(dir: Vector3) -> Vector3:
	var reached := ring
	phase = Phase.IDLE
	ring = null
	just_released = true
	_rope.visible = false
	arrived.emit(reached)
	var flat := Vector3(dir.x, 0.0, dir.z)
	flat = flat.normalized() if flat.length() > 0.05 else Vector3.ZERO
	return flat * tuning.grapple_release_carry + Vector3.UP * tuning.grapple_hop_velocity()


## Horizontal direction to the ring being reeled to (for facing).
func ring_direction() -> Vector3:
	if ring == null:
		return Vector3.ZERO
	var to := ring.global_position - player.global_position
	to.y = 0.0
	return to.normalized() if to.length() > 0.05 else Vector3.ZERO


## Stretch the rope from the tail tip to the ring (or part way while thrown).
func update_rope() -> void:
	if not is_active() or not is_instance_valid(ring):
		_rope.visible = false
		return
	var from := player.visual.to_global(TAIL_TIP)
	var to := ring.global_position
	if phase == Phase.THROW:
		to = from.lerp(to, clampf(phase_time / maxf(tuning.grapple_throw_time, 0.001), 0.1, 1.0))
	var span := to - from
	var length := span.length()
	if length < 0.05:
		_rope.visible = false
		return
	_rope.visible = true
	var y := span / length
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	_rope.global_transform = Transform3D(Basis(x, y * length, z), (from + to) * 0.5)
