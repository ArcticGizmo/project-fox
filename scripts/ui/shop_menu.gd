class_name ShopMenu
extends CanvasLayer
## The Magpie Peddler's wares (opened by ringing a stall bell). Pauses the game
## like the pause menu and is navigable the same way (D-pad/stick + A/B,
## keyboard, mouse). Rows: ammo refill, then every locked weapon in wheel order
## with its price. Rows you can't afford stay focusable (so you can read them)
## but buying them just clanks. Buying equips the weapon. B / Esc / Start leaves.

signal purchased(item: StringName)
signal closed

const GLIMMER_COLOR := Color(0.45, 1.0, 0.88)
const REFILL := &"refill"
const GREETINGS: Array[String] = [
	"Shiny, shiny! What'll it be?",
	"Ooh, glimmer! Spend it here, spend it now!",
	"One for sorrow, two for joy, three for a weapon, eh?",
]

var is_open: bool = false
var player: Player

var _title: Label
var _balance: Label
var _greeting: Label
var _list: VBoxContainer
var _scroll: ScrollContainer
var _detail: Label
var _leave: Button
## Row button -> item id (REFILL or a weapon id).
var _rows: Dictionary = {}
var _mouse_mode_before: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _opened_count: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 21
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.12, 0.96)
	style.border_color = Color(0.2, 0.55, 0.55)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override(&"panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	box.custom_minimum_size = Vector2(620, 0)
	panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	_title = _label(header, "Magpie Peddler", 36, Color(0.92, 0.86, 0.7))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_balance = _label(header, "", 30, GLIMMER_COLOR)
	_greeting = _label(box, "", 20, Color(1, 1, 1, 0.7))

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(620, 430)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	box.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 6)
	_scroll.add_child(_list)

	_detail = _label(box, "", 18, Color(1, 1, 1, 0.8))
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(620, 72)
	_leave = _button(box, "Leave", close)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		close()
		get_viewport().set_input_as_handled()


func open(p_player: Player) -> void:
	if is_open or p_player == null or p_player.is_dead:
		return
	player = p_player
	is_open = true
	visible = true
	_greeting.text = "\"%s\"" % GREETINGS[_opened_count % GREETINGS.size()]
	_opened_count += 1
	get_tree().paused = true
	_mouse_mode_before = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_rebuild()
	_focus_first()


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = _mouse_mode_before
	closed.emit()


## Buys a row's item (REFILL or a weapon id). Returns whether it was bought.
func buy(item: StringName) -> bool:
	if player == null:
		return false
	var ok := Shop.refill(player) if item == REFILL else Shop.buy_weapon(player, item)
	if not ok:
		Sfx.play(&"locked")
		return false
	Sfx.play(&"purchase")
	if item != REFILL:
		player.select_weapon(player.weapons.find(player.weapon_by_id(item)))
	purchased.emit(item)
	_rebuild()
	_focus_first()
	return true


## Item ids currently listed, top to bottom.
func listed_items() -> Array[StringName]:
	var out: Array[StringName] = []
	for b: Button in _list.get_children():
		out.append(_rows[b] as StringName)
	return out


func _rebuild() -> void:
	for c: Node in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_rows.clear()
	_balance.text = "%d glimmer" % player.glimmer
	var refill := Shop.refill_cost(player)
	_row(REFILL, "Refill all ammo", refill, Color(1.0, 0.85, 0.35),
			"Tops up every weapon you own." if refill > 0 else "Every weapon is already full.")
	for w: Weapon in Shop.stock(player):
		_row(w.data.id, w.data.display_name, w.data.price, w.data.color, w.data.description)
	if _list.get_child_count() == 1 and refill <= 0:
		_greeting.text = "\"Sold out of everything, you magnificent hoarder!\""


func _row(item: StringName, text: String, price: int, color: Color, detail: String) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(600, 46)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override(&"font_size", 22)
	var affordable := price > 0 and Shop.can_afford(player, price)
	b.text = "  " + text
	b.add_theme_color_override(&"font_color", color if affordable else color.darkened(0.55))
	b.add_theme_color_override(&"font_focus_color", Color.WHITE if affordable else Color(1, 1, 1, 0.45))
	b.set_meta(&"affordable", affordable)
	var tag := Label.new()
	tag.text = ("%d" % price) if price > 0 else "-"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_font_size_override(&"font_size", 22)
	tag.add_theme_color_override(&"font_color", GLIMMER_COLOR if affordable else GLIMMER_COLOR.darkened(0.6))
	b.add_child(tag)
	tag.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	tag.offset_left = -140
	tag.offset_right = -16
	b.pressed.connect(func() -> void: buy(item))
	b.focus_entered.connect(func() -> void:
		var note := "" if affordable or price <= 0 else "  (need %d more)" % (price - player.glimmer)
		_detail.text = detail + note)
	_list.add_child(b)
	_rows[b] = item


## The first row you can afford, else the first weapon, else Leave.
func _focus_first() -> void:
	var rows := _list.get_children()
	for b: Button in rows:
		if b.get_meta(&"affordable", false):
			b.grab_focus()
			return
	if rows.size() > 1:
		(rows[1] as Button).grab_focus()
	elif not rows.is_empty() and Shop.refill_cost(player) > 0:
		(rows[0] as Button).grab_focus()
	else:
		_leave.grab_focus()


func _label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", color)
	parent.add_child(l)
	return l


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 48)
	b.add_theme_font_size_override(&"font_size", 22)
	b.pressed.connect(action)
	parent.add_child(b)
	return b
