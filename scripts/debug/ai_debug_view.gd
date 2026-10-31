class_name AiDebugView
extends Node3D
## Awareness debug overlay for one enemy (DebugSettings.show_ai, F4 / pause menu).
## Only exists while the toggle is on: Enemy creates it and frees it again.
## Drawn in world space (top_level), rebuilt every frame with an ImmediateMesh.
##
##   cone       sight range + fov at eye height; grey-blue at 0 suspicion, shifting
##              to orange as it fills (bright centre line = suspicion fraction);
##              red full circle (aware sight range) once aware
##   cyan ring  hearing_range            purple ring  alert_radius
##   brown dashed ring  leash_radius around home  white post   home (+ heading tick)
##   pale green patrol points and route  white X      investigate / last-seen point
##   LOS line   eye -> target: green clear, red blocked, grey out of cone
##   magenta    group alert link alerter -> alerted (fades over LINK_TIME)
##   rings      NoiseEvent pulses (one view draws them for everyone): expand to the
##              noise radius, then fade; white if someone heard it, pale blue if not
## The label shows name, state + time, aware, suspicion bar and fill/drain trend.

const SEGMENTS := 40
const LINK_TIME := 1.5
const PULSE_GROW := 0.35
const CALM := Color(0.45, 0.6, 0.9)
const SUSPICIOUS := Color(1.0, 0.5, 0.1)
const AWARE := Color(1.0, 0.15, 0.15)
const HEARING := Color(0.2, 0.9, 0.95, 0.7)
const ALERT_RING := Color(0.7, 0.35, 1.0, 0.45)
const LEASH := Color(0.85, 0.5, 0.2, 0.6)
const HOME := Color(1, 1, 1, 0.9)
const PATROL := Color(0.6, 1.0, 0.6, 0.8)
const LOS_CLEAR := Color(0.2, 1.0, 0.3)
const LOS_BLOCKED := Color(1.0, 0.15, 0.15)
const LOS_OUT := Color(0.6, 0.6, 0.6, 0.6)
const LINK := Color(1.0, 0.3, 0.9)

## The view that draws noise pulses (so they are not drawn once per enemy).
static var _noise_owner: AiDebugView = null

var enemy: Enemy
var label: Label3D
var _mesh: ImmediateMesh
var _mi: MeshInstance3D
var _prev_suspicion: float = 0.0
var _trend: float = 0.0
var _has_lines: bool = false


static func attach(e: Enemy) -> AiDebugView:
	var v := AiDebugView.new()
	v.name = "AiDebugView"
	v.enemy = e
	e.add_child(v)
	return v


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mesh = ImmediateMesh.new()
	_mi = MeshInstance3D.new()
	_mi.mesh = _mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	mat.render_priority = 9
	_mi.material_override = mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 30
	label.outline_size = 10
	# Constant on-screen size so it stays readable from across the arena.
	label.fixed_size = true
	label.pixel_size = 0.0008
	label.render_priority = 11
	label.outline_render_priority = 10
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(label)
	_prev_suspicion = enemy.suspicion
	if _noise_owner == null or not is_instance_valid(_noise_owner):
		_noise_owner = self
	_redraw(0.0)


func _exit_tree() -> void:
	if _noise_owner == self:
		_noise_owner = null


func _process(delta: float) -> void:
	_redraw(delta)


## True once the mesh holds at least one real line (tests).
func has_lines() -> bool:
	return _has_lines


func draws_noise() -> bool:
	return _noise_owner == self


func _redraw(delta: float) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if _noise_owner == null or not is_instance_valid(_noise_owner):
		_noise_owner = self
	var s := enemy.suspicion
	if delta > 0.0:
		_trend = lerpf(_trend, (s - _prev_suspicion) / delta, 0.3)
	_prev_suspicion = s
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_has_lines = false
	var dead := enemy.health.is_dead
	if not dead:
		_draw_enemy(s)
	if draws_noise():
		_draw_noise()
	var real := _has_lines
	if not real:
		# An empty surface is an error; keep one invisible degenerate line.
		_line(enemy.global_position, enemy.global_position, Color(0, 0, 0, 0))
	_has_lines = real
	_mesh.surface_end()
	label.visible = not dead
	if not dead:
		label.global_position = enemy.global_position + Vector3.UP * (enemy.extents().y + 0.95)
		label.text = _text(s)
		label.modulate = AWARE.lerp(Color.WHITE, 0.3) if enemy.aware else CALM.lerp(SUSPICIOUS, s).lerp(Color.WHITE, 0.4)


func _text(s: float) -> String:
	var filled := roundi(s * 10.0)
	var bar := "#".repeat(filled) + ".".repeat(10 - filled)
	var trend := " ^fill" if _trend > 0.02 else (" v drain" if _trend < -0.02 else "")
	var extra := ""
	if enemy.is_alert_pending():
		extra = "\nalerted by %s" % (enemy.alerted_by.display_name if is_instance_valid(enemy.alerted_by) else "?")
	return "%s\n%s %.1fs  aware:%s\n[%s] %.2f%s%s" % [enemy.display_name, enemy.state, enemy.state_time,
			"Y" if enemy.aware else "n", bar, s, trend, extra]


func _draw_enemy(s: float) -> void:
	var e := enemy
	var pos := e.global_position
	var eye := e.eye_point()
	var feet := pos + Vector3.UP * 0.05
	if e.aware:
		_ring(Vector3(pos.x, eye.y, pos.z), e.sight_range * Enemy.AWARE_SIGHT_FACTOR, Color(AWARE, 0.6), 64)
	else:
		var tint := CALM.lerp(SUSPICIOUS, s)
		var fwd := e.forward()
		var half := deg_to_rad(e.sight_fov_deg * 0.5)
		var r := e.sight_range
		var prev := eye + fwd.rotated(Vector3.UP, -half) * r
		_line(eye, prev, tint)
		for i: int in range(1, SEGMENTS + 1):
			var a := -half + 2.0 * half * float(i) / SEGMENTS
			var p := eye + fwd.rotated(Vector3.UP, a) * r
			_line(prev, p, tint)
			prev = p
		_line(eye, prev, tint)
		# Suspicion as the filled fraction of the centre line.
		_line(eye, eye + fwd * r * s, Color(1.0, 0.75, 0.5))
		_line(eye + fwd * r * s, eye + fwd * r, Color(tint, 0.3))
		_ring(Vector3(pos.x, eye.y, pos.z), e.point_blank_range, Color(tint, 0.5), 20)
	_ring(feet, e.hearing_range, HEARING)
	if e.alert_radius > 0.0:
		_ring(feet + Vector3.UP * 0.05, e.alert_radius, ALERT_RING)
	var home := e.home_position
	if e.leash_radius > 0.0:
		_ring(home + Vector3.UP * 0.08, e.leash_radius, LEASH, 64, true)
	_line(home, home + Vector3.UP * 1.5, HOME)
	_line(home + Vector3.UP * 1.5, home + Vector3.UP * 1.5 + Vector3.FORWARD.rotated(Vector3.UP, e.home_yaw) * 0.6, HOME)
	_cross(home + Vector3.UP * 0.05, 0.35, HOME)
	var n := e.patrol_points.size()
	for i: int in n:
		var p := e.patrol_points[i]
		_diamond(p + Vector3.UP * 0.3, 0.25, PATROL)
		if n > 1:
			_line(p + Vector3.UP * 0.3, e.patrol_points[(i + 1) % n] + Vector3.UP * 0.3, Color(PATROL, 0.45))
	if e.state == Enemy.INVESTIGATE or e.state == Enemy.SUSPICIOUS:
		var goal := e.investigate_point if e.state == Enemy.INVESTIGATE else e.last_seen_position
		_cross(goal + Vector3.UP * 0.05, 0.5, Color.WHITE)
		_line(feet, goal + Vector3.UP * 0.05, Color(1, 1, 1, 0.35))
	if e.has_target():
		var aim := e.target.global_position + Vector3.UP * 0.9
		if e.target.has_method(&"get_aim_point"):
			aim = e.target.call(&"get_aim_point")
		if e.aware or eye.distance_to(aim) <= e.sight_range:
			var c := LOS_OUT
			if e.los_checked:
				c = LOS_BLOCKED if e.los_blocked else LOS_CLEAR
			_line(eye, aim, c)
	if is_instance_valid(e.alerted_by) and e.alerted_at >= 0.0:
		var age := e.age_seconds() - e.alerted_at
		if age <= LINK_TIME:
			var from := e.alerted_by.eye_point() + Vector3.UP * 0.3
			var to := eye + Vector3.UP * 0.3
			var c := Color(LINK, 1.0 - age / LINK_TIME * 0.7)
			_line(from, to, c)
			var dir := (to - from).normalized()
			var side := dir.cross(Vector3.UP).normalized() * 0.3
			_line(to, to - dir * 0.5 + side, c)
			_line(to, to - dir * 0.5 - side, c)


func _draw_noise() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for r: Dictionary in NoiseEvent.recent_emits():
		var age := now - float(r[&"time"])
		var radius := float(r[&"radius"])
		var at := r[&"position"] as Vector3
		var fade := clampf(1.0 - age / NoiseEvent.RECORD_TIME, 0.0, 1.0)
		var base := Color.WHITE if int(r[&"heard"]) > 0 else Color(0.6, 0.8, 1.0)
		var grown := radius * clampf(age / PULSE_GROW, 0.05, 1.0)
		_ring(at + Vector3.UP * 0.15, grown, Color(base, fade), 48)
		_ring(at + Vector3.UP * 0.25, radius, Color(base, fade * 0.5), 48)
		_cross(at + Vector3.UP * 0.15, 0.4, Color(base, fade))


func _line(a: Vector3, b: Vector3, c: Color) -> void:
	_mesh.surface_set_color(c)
	_mesh.surface_add_vertex(a)
	_mesh.surface_set_color(c)
	_mesh.surface_add_vertex(b)
	_has_lines = true


func _ring(center: Vector3, r: float, c: Color, segments: int = SEGMENTS, dashed: bool = false) -> void:
	for i: int in segments:
		if dashed and i % 2 == 1:
			continue
		var a0 := TAU * float(i) / segments
		var a1 := TAU * float(i + 1) / segments
		_line(center + Vector3(cos(a0), 0, sin(a0)) * r, center + Vector3(cos(a1), 0, sin(a1)) * r, c)


func _cross(at: Vector3, size: float, c: Color) -> void:
	_line(at + Vector3(-size, 0, -size), at + Vector3(size, 0, size), c)
	_line(at + Vector3(-size, 0, size), at + Vector3(size, 0, -size), c)


func _diamond(at: Vector3, size: float, c: Color) -> void:
	var pts: Array[Vector3] = [Vector3(size, 0, 0), Vector3(0, size, 0), Vector3(-size, 0, 0), Vector3(0, -size, 0)]
	for i: int in 4:
		_line(at + pts[i], at + pts[(i + 1) % 4], c)
