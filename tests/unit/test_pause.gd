extends TestCase
## Pause menu: pausing freezes gameplay, resume restores it, buttons work.

var menu: PauseMenu
var player: Player
var pad: ScriptedInputProvider


func before_each() -> void:
	add_floor()
	pad = ScriptedInputProvider.new()
	player = Player.new()
	player.input_provider = pad
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	menu = PauseMenu.new()
	add_child(menu)
	await wait_frames(5)


func _press_pause() -> void:
	var ev := InputEventAction.new()
	ev.action = &"pause"
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = &"pause"
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func test_pause_action_freezes_gameplay_and_resumes() -> void:
	await _press_pause()
	assert_true(menu.is_open and menu.visible, "menu open")
	assert_true(get_tree().paused, "tree paused")
	var before := player.global_position
	pad.next.move = Vector2(0, -1)
	await wait_frames(20)
	assert_true(player.global_position.distance_to(before) < 0.001, "player frozen while paused")
	await _press_pause()
	assert_false(menu.is_open or get_tree().paused, "resumed")
	await wait_frames(20)
	assert_true(player.global_position.distance_to(before) > 0.5, "player moves again")


func test_resume_button_has_focus_for_controller() -> void:
	menu.open()
	await get_tree().process_frame
	var focused := get_viewport().gui_get_focus_owner() as Button
	assert_true(focused != null and focused.text == "Resume", "Resume focused so A resumes immediately")
	menu.close()


func test_restart_emits_and_unpauses() -> void:
	var restarts: Array[int] = [0]
	menu.restart_requested.connect(func() -> void: restarts[0] += 1)
	menu.open()
	menu.call(&"_on_restart")
	assert_eq(restarts[0], 1, "restart requested")
	assert_false(get_tree().paused, "unpaused before the scene reloads")


func test_hitbox_toggle_button() -> void:
	menu.open()
	menu.call(&"_on_toggle_boxes")
	assert_true(DebugSettings.show_boxes, "toggled on from the menu")
	menu.call(&"_on_toggle_boxes")
	assert_false(DebugSettings.show_boxes, "and off")
	menu.close()
