class_name AwarenessMarker
extends Node3D
## "?" / "!" above an unaware enemy. Always on in normal play (not a debug view).
##   ?  pale grey-blue, brightening, with a bar that fills with suspicion
##      (SUSPICIOUS / INVESTIGATE).
##   !  white with a blue outline (ALERT, or a pending group alert).
## Hidden at rest and once aware. Deliberately no yellow: yellow emission is the
## attack wind-up colour (Enemy.TELEGRAPH_COLOR).

const DIM := Color(0.55, 0.62, 0.75)
const BRIGHT := Color(0.92, 0.97, 1.0)
const OUTLINE := Color(0.08, 0.16, 0.38)
const BAR_WIDTH := 0.8
const BAR_HEIGHT := 0.11

var enemy: Enemy
var question: Label3D
var exclaim: Label3D
var _bar: Node3D
var _bar_fill: MeshInstance3D


static func attach(e: Enemy) -> AwarenessMarker:
	var m := AwarenessMarker.new()
	m.name = "AwarenessMarker"
	m.enemy = e
	m.position.y = e.extents().y + 0.9
	e.add_child(m)
	return m


func _ready() -> void:
	question = _glyph("?")
	exclaim = _glyph("!")
	exclaim.modulate = BRIGHT
	exclaim.font_size = 120
	_bar = Node3D.new()
	_bar.position.y = -0.55
	add_child(_bar)
	_bar.add_child(_quad(BAR_WIDTH + 0.04, BAR_HEIGHT + 0.04, Color(0.05, 0.08, 0.15, 0.75), 0))
	_bar_fill = _quad(BAR_WIDTH, BAR_HEIGHT, BRIGHT, 1)
	_bar.add_child(_bar_fill)
	refresh()


func _process(_delta: float) -> void:
	refresh()


## Which glyph is showing: &"?", &"!" or &"".
func mode() -> StringName:
	if enemy == null or enemy.health == null or enemy.health.is_dead or enemy.aware:
		return &""
	if enemy.state == Enemy.ALERT or enemy.is_alert_pending():
		return &"!"
	if enemy.state == Enemy.SUSPICIOUS or enemy.state == Enemy.INVESTIGATE:
		return &"?"
	return &""


func refresh() -> void:
	var m := mode()
	visible = m != &""
	if not visible:
		return
	question.visible = m == &"?"
	_bar.visible = m == &"?"
	exclaim.visible = m == &"!"
	var s := clampf(enemy.suspicion, 0.0, 1.0)
	question.modulate = DIM.lerp(BRIGHT, s)
	question.scale = Vector3.ONE * (0.85 + 0.3 * s)
	_bar_fill.scale.x = maxf(s, 0.001)
	_bar_fill.position.x = -BAR_WIDTH * 0.5 * (1.0 - s)
	# Face the camera (the bar is plain quads, not billboards).
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		var to := cam.global_position - global_position
		if to.length_squared() > 0.01:
			_bar.global_basis = Basis.looking_at(-to, Vector3.UP)


func _glyph(text: String) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 110
	l.outline_size = 22
	l.outline_modulate = OUTLINE
	l.pixel_size = 0.008
	l.render_priority = 5
	l.outline_render_priority = 4
	add_child(l)
	return l


func _quad(w: float, h: float, c: Color, priority: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	mi.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 6 + priority
	mat.albedo_color = c
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
