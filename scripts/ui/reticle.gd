class_name Reticle
extends Control
## Screen-centre reticle. Small cross normally, red when aim assist has a
## target, and a scope ring with long cross-hairs when zoomed. A brass ring
## around it means jump will grapple (GrappleTail.is_ready()).

var locked: bool = false:
	set(value):
		if value != locked:
			locked = value
			queue_redraw()
var zoomed: bool = false:
	set(value):
		if value != zoomed:
			zoomed = value
			queue_redraw()
## 0..1 charge of the current weapon (0 hides the arc).
var charge: float = 0.0:
	set(value):
		if not is_equal_approx(value, charge):
			charge = value
			queue_redraw()
var grapple_ready: bool = false:
	set(value):
		if value != grapple_ready:
			grapple_ready = value
			queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _draw() -> void:
	var c := size * 0.5
	var col := Color(1, 0.3, 0.2) if locked else Color(1, 1, 1, 0.85)
	if zoomed:
		var r := minf(size.x, size.y) * 0.38
		draw_arc(c, r, 0.0, TAU, 96, Color(0, 0, 0, 0.6), 6.0, true)
		draw_arc(c, r, 0.0, TAU, 96, Color(1, 1, 1, 0.5), 2.0, true)
		draw_line(c + Vector2(-r, 0), c + Vector2(-6, 0), col, 1.5, true)
		draw_line(c + Vector2(6, 0), c + Vector2(r, 0), col, 1.5, true)
		draw_line(c + Vector2(0, -r), c + Vector2(0, -6), col, 1.5, true)
		draw_line(c + Vector2(0, 6), c + Vector2(0, r), col, 1.5, true)
		draw_circle(c, 2.0, col)
	else:
		for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(c + d * 4.0, c + d * 11.0, col, 2.0, true)
	if grapple_ready:
		draw_arc(c, 17.0, 0.0, TAU, 48, Color(0, 0, 0, 0.5), 5.0, true)
		draw_arc(c, 17.0, 0.0, TAU, 48, GrappleRing.HIGHLIGHT_COLOR, 2.5, true)
	if charge > 0.0:
		var arc_col := Color(1, 1, 1) if charge >= 1.0 else Color(1, 1, 1, 0.6)
		draw_arc(c, 24.0, -PI * 0.5, -PI * 0.5 + TAU * charge, 48, Color(0, 0, 0, 0.5), 6.0, true)
		draw_arc(c, 24.0, -PI * 0.5, -PI * 0.5 + TAU * charge, 48, arc_col, 3.0, true)
