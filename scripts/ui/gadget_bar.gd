class_name GadgetBar
extends Control
## HUD row of the four gadgets, in their gate colours (GadgetGate.GATE_COLORS).
## Locked: a dim outline. Unlocked: filled. Lit (bright border, slight swell)
## while the gadget is ready or in use: a grapple ring in reach, gliding,
## underground. The conduit slot carries one pip per storable charge, filled
## arc-blue while charged.

const SLOT := Vector2(64, 30)
const GAP := 8.0
const PIP_RADIUS := 5.0
const LOCKED_ALPHA := 0.25

var player: Player
var _age: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2((SLOT.x + GAP) * Gadgets.ALL.size(), SLOT.y + 22.0)


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()


## Ready or in use right now (the slot lights up).
func is_lit(id: StringName) -> bool:
	if player == null or not player.has_gadget(id):
		return false
	match id:
		Gadgets.GRAPPLE:
			return player.grapple.is_ready() or player.grapple.is_active()
		Gadgets.GLIDE:
			return player.is_gliding()
		Gadgets.BURROW:
			return player.burrow.is_active()
		Gadgets.CONDUIT:
			return player.conduit.is_charged()
	return false


func _draw() -> void:
	if player == null:
		return
	var font := get_theme_default_font()
	for i: int in Gadgets.ALL.size():
		var id := Gadgets.ALL[i]
		var c: Color = GadgetGate.GATE_COLORS[id]
		var unlocked := player.has_gadget(id)
		var lit := is_lit(id)
		var rect := Rect2(Vector2(i * (SLOT.x + GAP), 0), SLOT)
		if lit:
			rect = rect.grow(2.0)
		draw_rect(rect, Color(0, 0, 0, 0.45))
		if unlocked:
			draw_rect(rect.grow(-3.0), c.lightened(0.25) if lit else c)
		var border := Color(1, 1, 1, 0.9) if lit else Color(c.lightened(0.3), 1.0 if unlocked else LOCKED_ALPHA)
		draw_rect(rect, border, false, 2.0)
		var text: String = Gadgets.SHORT_NAMES[id]
		var text_col := Color(1, 1, 1, 1.0 if unlocked else 0.35)
		draw_string_outline(font, Vector2(rect.position.x, SLOT.y + 16.0), text, HORIZONTAL_ALIGNMENT_CENTER, SLOT.x, 13, 4, Color(0, 0, 0, text_col.a))
		draw_string(font, Vector2(rect.position.x, SLOT.y + 16.0), text, HORIZONTAL_ALIGNMENT_CENTER, SLOT.x, 13, text_col)
		if id == Gadgets.CONDUIT and unlocked:
			_draw_pips(rect)


func _draw_pips(rect: Rect2) -> void:
	var count := player.tuning.conduit_max_charges
	var charges := player.conduit.charges
	var spacing := PIP_RADIUS * 2.6
	var start := rect.get_center() - Vector2(spacing * (count - 1) * 0.5, 0)
	for p: int in count:
		var at := start + Vector2(spacing * p, 0)
		draw_circle(at, PIP_RADIUS + 1.5, Color(0, 0, 0, 0.6))
		if p < charges:
			var pulse := 0.8 + 0.2 * sin(_age * 9.0)
			draw_circle(at, PIP_RADIUS, Color(ConduitGauntlet.CHARGE_COLOR * pulse, 1.0))
		else:
			draw_arc(at, PIP_RADIUS - 1.0, 0.0, TAU, 16, Color(1, 1, 1, 0.5), 1.5)
