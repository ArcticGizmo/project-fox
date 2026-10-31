extends TestCase
## Player movement/combat with scripted input. Expected numbers derive from
## PlayerTuning so retuning feel does not break the tests.

var player: Player
var pad: ScriptedInputProvider


func before_each() -> void:
	add_floor()
	pad = ScriptedInputProvider.new()
	player = Player.new()
	player.input_provider = pad
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	await wait_frames(10)


func test_runs_at_tuned_speed_relative_to_camera() -> void:
	pad.next.move = Vector2(0, -1)
	await wait_seconds(1.0)
	var h := Vector3(player.velocity.x, 0, player.velocity.z)
	assert_near(h.length(), player.tuning.run_speed, 0.05, "top speed")
	assert_true(player.global_position.z < -7.0, "moved forward (camera yaw 0 = -Z), z=%.2f" % player.global_position.z)
	assert_near(player.global_position.x, 0.0, 0.01, "no drift")
	pad.next.move = Vector2.ZERO
	await wait_seconds(0.3)
	assert_true(Vector3(player.velocity.x, 0, player.velocity.z).length() < 0.01, "stops when stick released")


func _horizontal_speed() -> float:
	return Vector3(player.velocity.x, 0, player.velocity.z).length()


func test_strafe_is_slower_and_slowest_backwards() -> void:
	pad.next.strafe_held = true
	pad.next.move = Vector2(1, 0)
	await wait_seconds(0.6)
	var t := player.tuning
	assert_near(_horizontal_speed(), t.run_speed * t.strafe_speed_multiplier, 0.05, "sideways strafe speed")
	pad.next.move = Vector2(0, 1)
	await wait_seconds(0.6)
	assert_near(_horizontal_speed(), t.run_speed * t.strafe_speed_multiplier * t.strafe_backpedal_multiplier, 0.05, "backpedal speed")


func test_strafe_faces_camera_not_movement() -> void:
	pad.next.strafe_held = true
	pad.next.move = Vector2(1, 0)
	await wait_seconds(0.5)
	assert_near(player.facing_yaw, player.camera_rig.yaw, 0.01, "faces camera while moving sideways")


func test_rifle_scope_zooms_and_slows() -> void:
	pad.next.weapon_slot = player.weapon_paths.find("res://data/weapons/owl_lens_rifle.tres")
	await wait_frames(1)
	pad.next.strafe_held = true
	pad.next.move = Vector2(0, -1)
	await wait_seconds(0.8)
	assert_true(player.is_zoomed(), "rifle + strafe = scoped")
	var w := player.current_weapon()
	assert_near(player.camera_rig.camera.fov, w.data.zoom_fov, 1.0, "scope FOV")
	assert_near(_horizontal_speed(), player.tuning.run_speed * player.tuning.zoom_move_multiplier, 0.05, "scoped move speed")
	assert_true(player.camera_rig.look_scale() < 0.5, "look speed reduced when scoped")


func test_unscoped_weapon_only_strafes() -> void:
	pad.next.weapon_slot = player.weapon_paths.find("res://data/weapons/hornet_swarm.tres")
	await wait_frames(1)
	pad.next.strafe_held = true
	await wait_seconds(0.8)
	assert_false(player.is_zoomed(), "hornets have no scope")
	assert_near(player.camera_rig.camera.fov, player.tuning.camera_fov, 0.5, "normal FOV")
	assert_near(player.camera_rig.spring.spring_length, player.tuning.strafe_camera_distance, 0.1, "strafe camera pulls in")


func _measure_apex(hold_frames: int) -> float:
	var start_y := player.global_position.y
	var apex := start_y
	pad.next.jump_pressed = true
	pad.next.jump_held = true
	for i: int in 90:
		if i == hold_frames:
			pad.next.jump_held = false
		await get_tree().physics_frame
		apex = maxf(apex, player.global_position.y)
	pad.next.jump_held = false
	return apex - start_y


func test_full_jump_reaches_tuned_height() -> void:
	var h := await _measure_apex(1000)
	assert_near(h, player.tuning.jump_height, 0.2, "held jump apex")


func test_short_hop_is_lower() -> void:
	var h := await _measure_apex(2)
	assert_true(h < player.tuning.jump_height * 0.6, "tap jump apex %.2f" % h)


func test_double_jump_goes_higher() -> void:
	pad.next.jump_pressed = true
	pad.next.jump_held = true
	await wait_seconds(0.35)
	pad.next.jump_pressed = true
	var apex := 0.0
	for _i: int in 90:
		await get_tree().physics_frame
		apex = maxf(apex, player.global_position.y)
	assert_true(apex > player.tuning.jump_height + 0.8, "double jump apex %.2f" % apex)


func test_dodge_grants_iframes() -> void:
	pad.next.move = Vector2(1, 0)
	pad.next.dodge_pressed = true
	await wait_frames(2)
	assert_true(player.is_dodging(), "dodging")
	assert_false(player.hurt_box.receive(DamageInfo.create(10.0, Vector3.ZERO)), "hit ignored during dodge")
	assert_eq(player.health.current, player.tuning.max_health, "no damage")
	await wait_seconds(player.tuning.dodge_duration)
	assert_true(player.global_position.x > 2.5, "dodge travelled, x=%.2f" % player.global_position.x)


func test_hurt_iframes_prevent_double_hits() -> void:
	assert_true(player.hurt_box.receive(DamageInfo.create(10.0, Vector3(0, 0, -2), 5.0)), "first hit lands")
	assert_false(player.hurt_box.receive(DamageInfo.create(10.0, Vector3.ZERO)), "second hit blocked")
	assert_eq(player.health.current, player.tuning.max_health - 10.0, "took one hit")
	await wait_seconds(player.tuning.hurt_iframes + 0.05)
	assert_true(player.hurt_box.receive(DamageInfo.create(10.0, Vector3.ZERO)), "vulnerable again")


func test_weapon_switching() -> void:
	var count := Player.DEFAULT_WEAPONS.size()
	assert_eq(player.weapons.size(), count, "full loadout")
	pad.next.weapon_next = true
	await wait_frames(1)
	assert_eq(player.current_weapon_index, 1, "next")
	pad.next.weapon_prev = true
	await wait_frames(1)
	pad.next.weapon_prev = true
	await wait_frames(1)
	assert_eq(player.current_weapon_index, count - 1, "prev wraps")
	pad.next.weapon_slot = 0
	await wait_frames(1)
	assert_eq(player.current_weapon_index, 0, "direct slot")


func test_aim_assist_and_fire_hits_enemy_ahead() -> void:
	var rat := spawn_enemy("res://scenes/enemies/clockwork_rat.tscn", Vector3(1.0, 0, -10))
	rat.set_physics_process(false)  # hold still (PROCESS_MODE_DISABLED would also remove its collision)
	pad.next.weapon_slot = player.weapon_paths.find("res://data/weapons/owl_lens_rifle.tres")
	await wait_frames(2)
	assert_eq(player.aim_target, rat, "aim assist locks the rat")
	pad.next.fire_held = true
	var hit := await wait_until(func() -> bool: return rat.health.current < rat.health.max_health, 1.0)
	pad.next.fire_held = false
	assert_true(hit, "rifle shot hit the rat")


func test_respawn_after_death() -> void:
	player.position = Vector3(5, 0.05, 5)
	player.health.apply_damage(DamageInfo.create(1000.0, Vector3.ZERO))
	assert_true(player.is_dead, "dead")
	await wait_seconds(Player.RESPAWN_DELAY + 0.1)
	assert_false(player.is_dead, "respawned")
	assert_eq(player.health.current, player.tuning.max_health, "full health")
	assert_true(player.global_position.distance_to(player.spawn_point) < 0.5, "back at spawn")
