extends TestCase
## Weapon wheel: direction maths, slow-motion, stick and mouse selection.

var player: Player
var pad: ScriptedInputProvider


func before_each() -> void:
	add_floor()
	pad = ScriptedInputProvider.new()
	player = Player.new()
	player.input_provider = pad
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	await wait_frames(5)


func test_direction_maps_to_clockwise_slots() -> void:
	assert_eq(WeaponWheel.index_for_direction(Vector2.UP, 8), 0, "up")
	assert_eq(WeaponWheel.index_for_direction(Vector2(1, -1), 8), 1, "up-right")
	assert_eq(WeaponWheel.index_for_direction(Vector2.RIGHT, 8), 2, "right")
	assert_eq(WeaponWheel.index_for_direction(Vector2.DOWN, 8), 4, "down")
	assert_eq(WeaponWheel.index_for_direction(Vector2.LEFT, 8), 6, "left")
	assert_eq(WeaponWheel.index_for_direction(Vector2(-0.1, -1), 8), 0, "just left of up still slot 0")
	assert_eq(WeaponWheel.index_for_direction(Vector2(-1, -1), 8), 7, "up-left wraps to last")
	for i: int in 8:
		assert_eq(WeaponWheel.index_for_direction(WeaponWheel.slot_direction(i, 8), 8), i, "round trip %d" % i)


func test_slowmo_sources_combine() -> void:
	GameFeel.set_slowmo(&"a", 0.5)
	GameFeel.set_slowmo(&"b", 0.1)
	assert_near(Engine.time_scale, 0.1, 0.0001, "slowest source wins")
	GameFeel.clear_slowmo(&"b")
	assert_near(Engine.time_scale, 0.5, 0.0001, "remaining source")
	GameFeel.reset()
	assert_near(Engine.time_scale, 1.0, 0.0001, "reset")


func test_hold_slows_time_and_stick_selects_on_release() -> void:
	pad.next.wheel_held = true
	await wait_frames(2)
	assert_true(player.wheel_open, "wheel open")
	assert_near(Engine.time_scale, player.tuning.wheel_time_scale, 0.0001, "time slowed")
	pad.next.look = Vector2(1, 0)
	await wait_frames(2)
	assert_eq(player.wheel_highlight, 2, "stick right highlights slot 3")
	pad.next.look = Vector2.ZERO
	await wait_frames(2)
	assert_eq(player.wheel_highlight, 2, "highlight stays when stick recentres")
	pad.next.wheel_held = false
	await wait_frames(2)
	assert_false(player.wheel_open, "closed")
	assert_eq(player.current_weapon_index, 2, "equipped highlighted weapon")
	assert_near(Engine.time_scale, 1.0, 0.0001, "time restored")


func test_mouse_selects_and_camera_is_frozen() -> void:
	var yaw := player.camera_rig.yaw
	pad.next.wheel_held = true
	await wait_frames(2)
	for _i: int in 3:
		pad.next.mouse_look = Vector2(0, 20)
		await wait_frames(1)
	assert_eq(player.wheel_highlight, 4, "mouse down highlights the bottom slot")
	assert_near(player.camera_rig.yaw, yaw, 0.0001, "camera ignores look input while open")
	pad.next.wheel_held = false
	await wait_frames(2)
	assert_eq(player.current_weapon_index, 4, "equipped")


func test_cannot_fire_with_wheel_open_and_death_closes_it() -> void:
	var w := player.current_weapon()
	var ammo := w.ammo
	pad.next.wheel_held = true
	pad.next.fire_held = true
	await wait_frames(5)
	assert_eq(w.ammo, ammo, "no shots while choosing")
	player.health.apply_damage(DamageInfo.create(1000.0, Vector3.ZERO))
	assert_false(player.wheel_open, "dying closes the wheel")
	assert_near(Engine.time_scale, 1.0, 0.0001, "and restores time")
