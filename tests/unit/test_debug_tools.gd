extends TestCase
## Pause menu Debug page and the DebugTools shortcuts behind it.

var player: Player


func before_each() -> void:
	add_floor()
	player = Player.new()
	player.input_provider = ScriptedInputProvider.new()
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	await wait_frames(2)


func test_max_all_weapons() -> void:
	DebugTools.max_all_weapons(player)
	for w: Weapon in player.weapons:
		assert_true(w.is_max_level(), "%s at max" % w.data.id)


func test_spawn_every_kind_in_front() -> void:
	for kind: StringName in DebugTools.enemy_kinds():
		var e := DebugTools.spawn_enemy(player, kind)
		assert_true(e != null, "%s spawned" % kind)
		assert_true(e.aware, "%s aware" % kind)
		var d := Vector2(e.global_position.x, e.global_position.z).distance_to(Vector2(player.global_position.x, player.global_position.z))
		assert_near(d, DebugTools.SPAWN_DISTANCE, 0.1, "%s in front at spawn distance" % kind)
		e.queue_free()
		await wait_frames(1)
	assert_true(DebugTools.enemy_kinds().has(&"stag"), "boss is spawnable")


func test_boss_to_phase_three() -> void:
	assert_false(DebugTools.boss_to_phase(get_tree(), 3), "no boss: nothing happens")
	var stag := DebugTools.spawn_enemy(player, &"stag") as FurnaceStag
	await wait_frames(2)
	assert_true(DebugTools.boss_to_phase(get_tree(), 3), "boss found")
	var phased := await wait_until(func() -> bool: return stag.phase == 3, stag.roar_time * 2.0 + 1.0)
	assert_true(phased, "roared into phase 3 (phase %d)" % stag.phase)


func test_god_mode_takes_no_damage() -> void:
	player.god_mode = true
	await wait_frames(1)
	assert_false(player.hurt_box.receive(DamageInfo.create(30.0, Vector3(0, 0, -3))), "hit refused")
	assert_eq(player.health.current, player.health.max_health, "full health")
	player.god_mode = false
	await wait_frames(1)
	assert_true(player.hurt_box.receive(DamageInfo.create(30.0, Vector3(0, 0, -3))), "hits land again")


func test_pause_menu_debug_page() -> void:
	var menu := PauseMenu.new()
	add_child(menu)
	await wait_frames(1)
	menu.open()
	assert_false(menu.is_debug_page(), "opens on the main page")
	menu.show_debug_page()
	assert_true(menu.is_debug_page(), "debug page shown")
	var god := menu.get(&"_god") as Button
	assert_eq(god.text, "Invulnerable: OFF", "god label")
	god.pressed.emit()
	assert_true(player.god_mode, "button toggles invulnerability")
	assert_eq(god.text, "Invulnerable: ON", "label follows")
	var spawn := menu.get(&"_spawn_kind") as Button
	var before := spawn.text
	spawn.pressed.emit()
	assert_true(spawn.text != before, "spawn kind cycles (%s -> %s)" % [before, spawn.text])
	assert_true((menu.get(&"_boss2") as Button).disabled, "boss buttons off without a boss")
	var rumble := menu.get(&"_rumble") as HSlider
	rumble.value = 0.5
	assert_near(GameFeel.rumble_strength, 0.5, 0.001, "rumble slider drives GameFeel")
	rumble.value = 1.0
	var press := InputEventAction.new()
	press.action = &"ui_cancel"
	press.pressed = true
	menu._unhandled_input(press)
	assert_false(menu.is_debug_page(), "back returns to the main page")
	assert_true(menu.is_open, "and keeps the menu open")
	menu.close()
	player.god_mode = false
