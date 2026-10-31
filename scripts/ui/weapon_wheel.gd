class_name WeaponWheel
extends Control
## Radial weapon select. Shown while the player holds the wheel button; the
## player owns selection (Player.wheel_open / wheel_highlight) and this only
## draws it. Slot 0 is at the top, then clockwise, matching number keys 1-8.

const RADIUS := 230.0
const SLOT_RADIUS := 50.0
const BACKDROP_RADIUS := 310.0

var player: Player


## Slot index for a stick/mouse direction (screen space: +x right, +y down).
static func index_for_direction(dir: Vector2, count: int) -> int:
	if count <= 0 or dir.length_squared() < 0.000001:
		return 0
	var angle := fposmod(atan2(dir.x, -dir.y), TAU)
	return roundi(angle / (TAU / count)) % count


## Screen-space unit direction of a slot's centre.
static func slot_direction(index: int, count: int) -> Vector2:
	var a := TAU * float(index) / float(count)
	return Vector2(sin(a), -cos(a))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


func _process(_delta: float) -> void:
	var should_show := player != null and player.wheel_open
	if should_show != visible:
		visible = should_show
	if visible:
		queue_redraw()


func _draw() -> void:
	if player == null or player.weapons.is_empty():
		return
	var font := ThemeDB.fallback_font
	var c := size * 0.5
	var page := player.wheel_page
	var first := page * Player.WHEEL_PAGE_SIZE
	var n := player.wheel_page_slots(page)
	draw_circle(c, BACKDROP_RADIUS, Color(0.05, 0.04, 0.03, 0.6))
	draw_arc(c, BACKDROP_RADIUS, 0.0, TAU, 96, Color(0.75, 0.6, 0.3, 0.8), 3.0, true)
	var pages := player.wheel_page_count()
	if pages > 1:
		var dots := ""
		for p: int in pages:
			dots += "●" if p == page else "○"
		draw_string(font, c + Vector2(-150, BACKDROP_RADIUS + 34), "LB  %s  RB" % dots, HORIZONTAL_ALIGNMENT_CENTER, 300, 22, Color(1, 0.85, 0.4))

	var hl := player.wheel_highlight

	for i: int in n:
		var w := player.weapons[first + i]
		var pos := c + slot_direction(i, n) * RADIUS
		var selected := first + i == hl
		var r := SLOT_RADIUS * (1.2 if selected else 1.0)
		var fill := w.data.color if selected else w.data.color.darkened(0.55)
		draw_circle(pos, r, fill)
		draw_arc(pos, r, 0.0, TAU, 48, Color.WHITE if selected else Color(1, 1, 1, 0.35), 3.0 if selected else 1.5, true)
		var label := "%d" % (i + 1)
		draw_string(font, pos + Vector2(-r, 8), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 26, Color.WHITE)
		var lv := "MAX" if w.is_max_level() else "Lv %d" % w.level
		draw_string(font, pos + Vector2(-r, r + 20), lv, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 16, Color(1, 1, 1, 0.85))
		if w.ammo <= 0:
			draw_string(font, pos + Vector2(-r, -r - 6), "EMPTY", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 14, Color(1, 0.35, 0.3))

	var cw := player.weapons[hl]
	var width := 300.0
	draw_string(font, c + Vector2(-width * 0.5, -22), cw.data.display_name, HORIZONTAL_ALIGNMENT_CENTER, width, 26, cw.data.color)
	draw_string(font, c + Vector2(-width * 0.5, 6), "Lv %d   Ammo %d / %d" % [cw.level, cw.ammo, cw.max_ammo()], HORIZONTAL_ALIGNMENT_CENTER, width, 18, Color.WHITE)
	draw_multiline_string(font, c + Vector2(-width * 0.5, 34), cw.data.description, HORIZONTAL_ALIGNMENT_CENTER, width, 14, 4, Color(1, 1, 1, 0.75))
