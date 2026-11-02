extends TestCase
## HUD gadget feedback: the gadget bar lights for gadgets in use, the conduit
## slot shows charges, and unlocking announces the gadget and how to use it.

var player: Player
var hud: Hud
var bar: GadgetBar


func before_each() -> void:
	add_floor()
	player = Player.new()
	player.input_provider = ScriptedInputProvider.new()
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	hud = Hud.new()
	add_child(hud)
	await wait_frames(2)
	hud.bind(player, null)
	bar = hud.get(&"_gadget_bar") as GadgetBar


func _popup() -> String:
	return (hud.get(&"_popup") as Label).text


func _detail() -> String:
	return (hud.get(&"_popup_detail") as Label).text


func test_unlock_announces_name_and_hint() -> void:
	player.unlock_gadget(Gadgets.GRAPPLE)
	assert_true(_popup().contains(Gadgets.NAMES[Gadgets.GRAPPLE]), "popup names it: %s" % _popup())
	assert_eq(_detail(), Gadgets.HINTS[Gadgets.GRAPPLE], "popup says how to use it")


func test_unlock_all_is_one_popup() -> void:
	player.gadgets.unlock_all()
	assert_true(_popup().begins_with("%d gadgets" % Gadgets.ALL.size()), "one popup for all: %s" % _popup())
	for id: StringName in Gadgets.ALL:
		assert_true(_detail().contains(Gadgets.SHORT_NAMES[id]), "lists %s" % id)


func test_every_gadget_has_hud_text() -> void:
	for id: StringName in Gadgets.ALL:
		assert_true(Gadgets.NAMES.has(id) and Gadgets.SHORT_NAMES.has(id) and Gadgets.HINTS.has(id), "%s has name, label and hint" % id)
		assert_true(GadgetGate.GATE_COLORS.has(id), "%s has a colour" % id)


func test_conduit_slot_lights_while_charged() -> void:
	assert_false(bar.is_lit(Gadgets.CONDUIT), "locked: dark")
	player.unlock_gadget(Gadgets.CONDUIT)
	assert_false(bar.is_lit(Gadgets.CONDUIT), "uncharged: dark")
	player.conduit.charges = 1
	assert_true(bar.is_lit(Gadgets.CONDUIT), "charged: lit")
	player.conduit.clear()
	assert_false(bar.is_lit(Gadgets.CONDUIT), "spent: dark again")


func test_glide_slot_lights_while_gliding() -> void:
	player.unlock_gadget(Gadgets.GLIDE)
	assert_false(bar.is_lit(Gadgets.GLIDE), "not gliding")
	player.cloak.open()
	assert_true(bar.is_lit(Gadgets.GLIDE), "gliding")
	player.close_glide()
	assert_false(bar.is_lit(Gadgets.GLIDE), "folded")


func test_locked_gadgets_never_light() -> void:
	player.cloak.open()
	player.conduit.charges = 1
	for id: StringName in Gadgets.ALL:
		assert_false(bar.is_lit(id), "%s locked: dark" % id)
	player.close_glide()
	player.conduit.clear()
