extends Node
## Global "juice": hit-stop, slow-motion, camera shake requests, damage
## numbers, impact puffs. Tests switch the timing-sensitive parts off
## (hit_stop_enabled = false).
##
## Engine.time_scale is owned here: it is the minimum of every active
## slow-motion source (e.g. the weapon wheel) and any running hit-stop, so
## sources never overwrite each other. Do not set Engine.time_scale elsewhere.

signal shake_requested(strength: float)

## Rumble from shake and hit-stop: strength per unit of shake, and per hit-stop.
const SHAKE_RUMBLE := Vector2(0.5, 1.0)
const HIT_STOP_RUMBLE := Vector2(0.45, 0.7)

var hit_stop_enabled: bool = true
var damage_numbers_enabled: bool = true
var rumble_enabled: bool = true
## Scales every rumble (an options slider later).
var rumble_strength: float = 1.0
## (weak, strong, seconds) of the last rumble started, for tests.
var last_rumble: Vector3 = Vector3.ZERO

var _rumble_end_ms: int = 0
var _rumble_level: float = 0.0

var _hit_stop_end_ms: int = 0
var _hit_stop_scale: float = 1.0
var _slowmo: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if _hit_stop_end_ms > 0 and Time.get_ticks_msec() >= _hit_stop_end_ms:
		_hit_stop_end_ms = 0
		_apply_time_scale()


## Briefly slows time so heavy hits "land". Duration is in real seconds.
func hit_stop(duration: float, time_scale: float = 0.05) -> void:
	if duration <= 0.0:
		return
	# Heavy hits always thump the pad, even with time-stopping off (tests).
	rumble(HIT_STOP_RUMBLE.x, HIT_STOP_RUMBLE.y, duration + 0.06)
	if not hit_stop_enabled:
		return
	_hit_stop_scale = time_scale
	_hit_stop_end_ms = maxi(_hit_stop_end_ms, Time.get_ticks_msec() + int(duration * 1000.0))
	_apply_time_scale()


## Holds time at `scale` until clear_slowmo(source). Several sources can overlap.
func set_slowmo(source: StringName, scale: float) -> void:
	_slowmo[source] = scale
	_apply_time_scale()


func clear_slowmo(source: StringName) -> void:
	_slowmo.erase(source)
	_apply_time_scale()


## Back to normal time (scene restart, between tests).
func reset() -> void:
	_slowmo.clear()
	_hit_stop_end_ms = 0
	_apply_time_scale()
	_rumble_end_ms = 0
	_rumble_level = 0.0
	last_rumble = Vector3.ZERO
	for pad: int in Input.get_connected_joypads():
		Input.stop_joy_vibration(pad)


func _apply_time_scale() -> void:
	var s := 1.0
	for v: float in _slowmo.values():
		s = minf(s, v)
	if _hit_stop_end_ms > 0:
		s = minf(s, _hit_stop_scale)
	Engine.time_scale = s


func shake(strength: float) -> void:
	shake_requested.emit(strength)
	var s := clampf(strength, 0.0, 1.0)
	rumble(SHAKE_RUMBLE.x * s, SHAKE_RUMBLE.y * s, 0.08 + 0.25 * s)


## Controller vibration on every connected pad: `weak` is the high-frequency
## motor (buzz), `strong` the low one (thump). A weaker request never cuts off a
## stronger one that is still running.
func rumble(weak: float, strong: float, duration: float) -> void:
	if not rumble_enabled or duration <= 0.0 or (weak <= 0.0 and strong <= 0.0):
		return
	var now := Time.get_ticks_msec()
	var level := maxf(weak, strong)
	if now < _rumble_end_ms and level < _rumble_level:
		return
	_rumble_level = level
	_rumble_end_ms = now + int(duration * 1000.0)
	last_rumble = Vector3(weak, strong, duration)
	for pad: int in Input.get_connected_joypads():
		Input.start_joy_vibration(pad, clampf(weak * rumble_strength, 0.0, 1.0), clampf(strong * rumble_strength, 0.0, 1.0), duration)


func damage_number(world_pos: Vector3, amount: float, critical: bool = false) -> void:
	if not damage_numbers_enabled:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var label := Label3D.new()
	label.text = str(roundi(amount)) + ("!" if critical else "")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 56 if critical else 36
	label.outline_size = 10
	label.pixel_size = 0.008
	label.modulate = Color(1.0, 0.8, 0.15) if critical else Color.WHITE
	label.position = world_pos + Vector3(randf_range(-0.3, 0.3), 0.2, randf_range(-0.3, 0.3))
	scene.add_child(label)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y + 1.2, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.25)
	tw.chain().tween_callback(label.queue_free)


## Expanding, fading sphere. Cheap stand-in for particles.
func impact(world_pos: Vector3, color: Color, size: float = 0.6, duration: float = 0.18) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = world_pos
	mi.scale = Vector3.ONE * size * 0.3
	scene.add_child(mi)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size, duration).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(mi.queue_free)
