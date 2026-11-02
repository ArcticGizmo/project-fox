class_name Hud
extends CanvasLayer
## Prototype HUD: health, current weapon (level, XP, ammo), weapon wheel,
## crosshair, wave counter, gadget bar (GadgetBar), level-up and gadget-unlock
## popups and debug hints.

const HELP_TEXT := "X / F: staff (in air: slam)    Y hold / Tab: weapon wheel (L-stick / mouse)    LB/RB, Q/E, 1-8: switch\nLT / RMB: strafe (rifle: scope)    B / Shift: dodge    Start / Esc: pause\nBack / F1: hitboxes    D-pad Up / F2: level weapon    D-pad Down / F3: next wave    F4 (or pause menu): AI debug"

var _player: Player
var _hp_bar: ProgressBar
var _hp_label: Label
var _weapon_label: Label
var _ammo_label: Label
var _xp_bar: ProgressBar
var _gadget_bar: GadgetBar
var _wheel: WeaponWheel
var _reticle: Reticle
var _wave_label: Label
var _popup: Label
## Second popup line: what the new weapon level adds.
var _popup_detail: Label
var _popup_box: VBoxContainer
var _popup_tween: Tween
var _unlock_batch: Array[StringName] = []
var _unlock_frame: int = -1


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top_left := _corner(root, Control.PRESET_TOP_LEFT, Vector2(24, 20))
	_hp_label = _label(top_left, "HP", 22)
	_hp_bar = _bar(top_left, Color(0.9, 0.25, 0.2), Vector2(300, 20))
	_gadget_bar = GadgetBar.new()
	top_left.add_child(_gadget_bar)

	var bottom_right := _corner(root, Control.PRESET_BOTTOM_RIGHT, Vector2(-24, -20))
	bottom_right.alignment = BoxContainer.ALIGNMENT_END
	_weapon_label = _label(bottom_right, "", 26)
	_ammo_label = _label(bottom_right, "", 22)
	_xp_bar = _bar(bottom_right, Color(0.4, 0.8, 1.0), Vector2(300, 12))
	for l: Label in [_weapon_label, _ammo_label]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var bottom_left := _corner(root, Control.PRESET_BOTTOM_LEFT, Vector2(24, -20))
	var help := _label(bottom_left, HELP_TEXT, 14)
	help.modulate.a = 0.6

	_wheel = WeaponWheel.new()
	root.add_child(_wheel)

	_reticle = Reticle.new()
	root.add_child(_reticle)

	_wave_label = Label.new()
	_wave_label.add_theme_font_size_override(&"font_size", 24)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_wave_label.offset_top = 16
	root.add_child(_wave_label)

	# Centred two-line popup (title + detail) that fades as one.
	_popup_box = VBoxContainer.new()
	_popup_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_popup_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_popup_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_popup_box.offset_top = 220
	_popup_box.modulate.a = 0.0
	root.add_child(_popup_box)
	_popup = Label.new()
	_popup.add_theme_font_size_override(&"font_size", 40)
	_popup.add_theme_color_override(&"font_color", Color(1, 0.85, 0.3))
	_popup.add_theme_constant_override(&"outline_size", 8)
	_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup_box.add_child(_popup)
	_popup_detail = Label.new()
	_popup_detail.add_theme_font_size_override(&"font_size", 26)
	_popup_detail.add_theme_constant_override(&"outline_size", 6)
	_popup_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup_box.add_child(_popup_detail)


func bind(player: Player, waves: WaveManager) -> void:
	_player = player
	_wheel.player = player
	_gadget_bar.player = player
	player.gadgets.unlocked_gadget.connect(_on_gadget_unlocked)
	player.health.changed.connect(_on_health_changed)
	player.weapon_changed.connect(_on_weapon_changed)
	player.weapon_leveled.connect(_on_weapon_leveled)
	for w: Weapon in player.weapons:
		w.ammo_changed.connect(func(_c: int, _m: int) -> void: _refresh_weapon())
		w.xp_changed.connect(func(_x: int, _n: int) -> void: _refresh_weapon())
	_on_health_changed(player.health.current, player.health.max_health)
	_refresh_weapon()
	if waves != null:
		waves.wave_started.connect(func(n: int) -> void: _wave_label.text = "Wave %d" % n)
		waves.wave_cleared.connect(func(n: int) -> void: _show_popup("Wave %d cleared!" % n))


func _process(_delta: float) -> void:
	if _player != null:
		_reticle.visible = not _player.wheel_open
		_reticle.locked = _player.aim_target != null
		_reticle.zoomed = _player.is_zoomed()
		_reticle.grapple_ready = _player.grapple != null and _player.grapple.is_ready()
		var w := _player.current_weapon()
		_reticle.charge = w.charge if w != null else 0.0


func _on_health_changed(current: float, maximum: float) -> void:
	_hp_bar.max_value = maximum
	_hp_bar.value = current
	_hp_label.text = "HP %d / %d" % [ceili(current), ceili(maximum)]


func _on_weapon_changed(_w: Weapon) -> void:
	_refresh_weapon()


func _on_weapon_leveled(w: Weapon, level: int) -> void:
	var top := "%s  MAX LEVEL!" % w.data.display_name if w.is_max_level() else "%s  Lv %d!" % [w.data.display_name, level]
	_show_popup(top, w.stats().perk, 2.4)
	_refresh_weapon()


func _refresh_weapon() -> void:
	if _player == null:
		return
	var w := _player.current_weapon()
	if w == null:
		return
	var lv := "MAX" if w.is_max_level() else str(w.level)
	_weapon_label.text = "%s  Lv %s" % [w.data.display_name, lv]
	_weapon_label.add_theme_color_override(&"font_color", w.data.color)
	_ammo_label.text = "%d / %d" % [w.ammo, w.max_ammo()]
	_xp_bar.max_value = maxi(1, w.xp_needed())
	_xp_bar.value = w.xp_needed() if w.is_max_level() else w.xp


func _show_popup(text: String, detail: String = "", hold: float = 1.2) -> void:
	_popup.text = text
	_popup_detail.text = detail
	if _popup_tween != null:
		_popup_tween.kill()
	_popup_detail.visible = detail != ""
	_popup_box.modulate.a = 1.0
	_popup_tween = create_tween()
	_popup_tween.tween_interval(hold)
	_popup_tween.tween_property(_popup_box, "modulate:a", 0.0, 0.5)


func _corner(root: Control, preset: Control.LayoutPreset, offset: Vector2) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	box.set_anchors_and_offsets_preset(preset)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN if offset.x < 0 else Control.GROW_DIRECTION_END
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN if offset.y < 0 else Control.GROW_DIRECTION_END
	box.position += offset
	return box


func _label(parent: Control, text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_constant_override(&"outline_size", 6)
	l.add_theme_color_override(&"font_outline_color", Color.BLACK)
	parent.add_child(l)
	return l


func _bar(parent: Control, fill: Color, min_size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = min_size
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	bar.add_theme_stylebox_override(&"background", bg)
	bar.add_theme_stylebox_override(&"fill", fg)
	parent.add_child(bar)
	return bar


func _on_gadget_unlocked(id: StringName) -> void:
	# Several in one frame (pause menu "Unlock All Gadgets"): one popup for the lot.
	var frame := Engine.get_process_frames()
	if frame != _unlock_frame:
		_unlock_frame = frame
		_unlock_batch.clear()
	_unlock_batch.append(id)
	if _unlock_batch.size() == 1:
		_show_popup("%s!" % Gadgets.NAMES[id], Gadgets.HINTS[id], 3.0)
	else:
		var names: PackedStringArray = []
		for g: StringName in _unlock_batch:
			names.append(Gadgets.SHORT_NAMES[g])
		_show_popup("%d gadgets unlocked!" % _unlock_batch.size(), ", ".join(names), 3.0)
