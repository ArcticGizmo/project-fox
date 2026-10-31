class_name CameraRig
extends Node3D
## Third-person orbit camera. Top-level so it can lag behind the player.
## Yaw/pitch come from the right stick or mouse; a SpringArm keeps it out of walls.

var target: Node3D
var tuning: PlayerTuning
var yaw: float = 0.0
var pitch: float = 0.0
var spring: SpringArm3D
var camera: Camera3D

var _follow: Vector3 = Vector3.ZERO
var _shake: float = 0.0


func _ready() -> void:
	top_level = true
	pitch = deg_to_rad(tuning.default_pitch_deg)
	spring = SpringArm3D.new()
	spring.name = "SpringArm"
	spring.spring_length = tuning.camera_distance
	spring.collision_mask = Layers.WORLD
	spring.margin = 0.2
	spring.position = Vector3(0, tuning.camera_vertical_offset, 0)
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	spring.shape = probe
	add_child(spring)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = tuning.camera_fov
	spring.add_child(camera)
	GameFeel.shake_requested.connect(add_shake)
	snap_to_target()


func apply_look(input: PlayerInputState, delta: float) -> void:
	var stick := input.look
	var mag := stick.length()
	if mag > 0.0:
		stick = stick / mag * pow(minf(mag, 1.0), tuning.look_response_exponent)
	var invert := -1.0 if tuning.invert_y else 1.0
	yaw -= stick.x * deg_to_rad(tuning.look_speed_yaw_deg) * delta
	yaw -= deg_to_rad(input.mouse_look.x * tuning.mouse_sensitivity)
	pitch -= stick.y * deg_to_rad(tuning.look_speed_pitch_deg) * delta * invert
	pitch -= deg_to_rad(input.mouse_look.y * tuning.mouse_sensitivity) * invert
	pitch = clampf(pitch, deg_to_rad(tuning.pitch_min_deg), deg_to_rad(tuning.pitch_max_deg))


func follow(delta: float) -> void:
	if target == null:
		return
	var desired := target.global_position + Vector3(0, tuning.camera_height, 0)
	var k := 1.0 - exp(-tuning.camera_follow_sharpness * delta)
	var kv := 1.0 - exp(-tuning.camera_vertical_sharpness * delta)
	_follow.x = lerpf(_follow.x, desired.x, k)
	_follow.z = lerpf(_follow.z, desired.z, k)
	_follow.y = lerpf(_follow.y, desired.y, kv)
	global_position = _follow
	rotation = Vector3(pitch, yaw, 0.0)
	_shake = maxf(0.0, _shake - tuning.shake_decay * delta)
	var s := _shake * _shake * tuning.max_shake_offset
	camera.h_offset = randf_range(-s, s)
	camera.v_offset = randf_range(-s, s)


func snap_to_target() -> void:
	if target == null:
		return
	_follow = target.global_position + Vector3(0, tuning.camera_height, 0)
	global_position = _follow
	rotation = Vector3(pitch, yaw, 0.0)


func add_shake(strength: float) -> void:
	_shake = minf(1.0, _shake + strength)


func get_aim_origin() -> Vector3:
	return camera.global_position


func get_aim_direction() -> Vector3:
	return -camera.global_basis.z
