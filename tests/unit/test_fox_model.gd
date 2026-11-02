extends TestCase


func _fox() -> FoxModel:
	var fox := FoxModel.new(Player.HEIGHT)
	add_child(fox)
	return fox


func test_clips_are_baked_and_loop() -> void:
	var fox := _fox()
	for clip: StringName in [&"Idle", &"Walk", &"Running", &"Jump", &"Fall"]:
		assert_true(fox.anim.has_animation(clip), "has %s" % clip)
		var a := fox.anim.get_animation(clip)
		assert_eq(a.loop_mode, Animation.LOOP_LINEAR, "%s loops" % clip)
	# Both legs and both arms are driven by the walk.
	var walk := fox.anim.get_animation(&"Walk")
	for bone: StringName in [FoxModel.L_THIGH, FoxModel.R_THIGH, FoxModel.L_ARM, FoxModel.R_ARM]:
		assert_true(walk.find_track(NodePath(FoxModel.SKELETON_PATH % bone), Animation.TYPE_ROTATION_3D) >= 0,
				"walk drives %s" % bone)


func test_speed_picks_idle_walk_run_with_hysteresis() -> void:
	var fox := _fox()
	fox.update(0.0, true)
	assert_eq(fox.anim.current_animation, &"Idle", "standing")
	fox.update(FoxModel.WALK_CLIP_SPEED, true)
	assert_eq(fox.anim.current_animation, &"Walk", "slow")
	assert_near(fox.anim.speed_scale, 1.0, 0.01, "walk plays at authored rate at its clip speed")
	var between := (FoxModel.RUN_ENTER_SPEED + FoxModel.RUN_EXIT_SPEED) * 0.5
	fox.update(between, true)
	assert_eq(fox.anim.current_animation, &"Walk", "walk holds until the enter speed")
	fox.update(FoxModel.RUN_ENTER_SPEED + 0.5, true)
	assert_eq(fox.anim.current_animation, &"Running", "fast")
	fox.update(between, true)
	assert_eq(fox.anim.current_animation, &"Running", "run holds until the exit speed")
	fox.update(FoxModel.RUN_EXIT_SPEED - 0.5, true)
	assert_eq(fox.anim.current_animation, &"Walk", "back to walk")
	fox.update(8.0, false, 5.0)
	assert_eq(fox.anim.current_animation, &"Jump", "rising")
	fox.update(8.0, false, -2.0)
	assert_eq(fox.anim.current_animation, &"Fall", "falling")


func test_one_shots_do_not_loop() -> void:
	var fox := _fox()
	for clip: StringName in [&"DoubleJump", &"Land", &"Dodge", &"Hurt"]:
		assert_eq(fox.anim.get_animation(clip).loop_mode, Animation.LOOP_NONE, "%s is a one-shot" % clip)


func test_landing_after_a_real_fall_squashes_then_returns_to_idle() -> void:
	var fox := _fox()
	for _i: int in 30:
		fox.update(0.0, false, -6.0)
		await wait_frames(1)
	fox.update(0.0, true)
	assert_eq(fox.anim.current_animation, &"Land", "lands")
	await wait_seconds(FoxModel.LAND_LENGTH + 0.05)
	fox.update(0.0, true)
	assert_eq(fox.anim.current_animation, &"Idle", "back to idle once the land ends")


func test_short_hop_lands_without_squash() -> void:
	var fox := _fox()
	fox.update(0.0, false, 3.0)
	await wait_frames(3)
	fox.update(0.0, true)
	assert_eq(fox.anim.current_animation, &"Idle", "no land for a tiny hop")


func test_hold_beats_actions_and_actions_beat_locomotion() -> void:
	var fox := _fox()
	fox.play_action(&"Hurt")
	fox.update(FoxModel.WALK_CLIP_SPEED, true)
	assert_eq(fox.anim.current_animation, &"Hurt", "hurt plays over the walk")
	fox.update(FoxModel.WALK_CLIP_SPEED, true, 0.0, &"Dodge")
	assert_eq(fox.anim.current_animation, &"Dodge", "dodge cuts the hurt short")
	assert_eq(fox.current_action(), &"", "action dropped")
	fox.update(FoxModel.WALK_CLIP_SPEED, true)
	assert_eq(fox.anim.current_animation, &"Walk", "back to walking after the dodge")


func test_player_double_jump_and_dodge_drive_the_model() -> void:
	add_floor()
	var pad := ScriptedInputProvider.new()
	var player := Player.new()
	player.input_provider = pad
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	await wait_frames(10)
	pad.next.jump_pressed = true
	pad.next.jump_held = true
	await wait_frames(10)
	pad.next.jump_pressed = true
	await wait_frames(2)
	assert_eq(player.fox_model.anim.current_animation, &"DoubleJump", "flip on the double jump")
	pad.next.jump_held = false
	await wait_until(func() -> bool: return player.is_on_floor(), 3.0)
	await wait_seconds(0.5)
	pad.next.dodge_pressed = true
	await wait_frames(2)
	assert_eq(player.fox_model.anim.current_animation, &"Dodge", "dodge pose while dodging")


func _player() -> Array:
	add_floor()
	var pad := ScriptedInputProvider.new()
	var player := Player.new()
	player.input_provider = pad
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	await wait_frames(10)
	return [player, pad]


func test_staff_combo_plays_each_swing_timed_to_the_tuning() -> void:
	var made: Array = await _player()
	var player: Player = made[0]
	var pad: ScriptedInputProvider = made[1]
	var seen: Array[StringName] = []
	for i: int in player.melee.combo_length():
		pad.next.melee_pressed = true
		await wait_frames(2)
		seen.append(player.fox_model.anim.current_animation)
		var expected := player.tuning.melee_swing_time[i]
		var a := player.fox_model.anim
		assert_near(a.current_animation_length / a.speed_scale, expected, 0.01, "swing %d lasts its swing time" % i)
		await wait_until(func() -> bool: return player.melee.combo_index != i or not player.melee.is_busy(), 1.0)
	assert_eq(seen, [&"SwingRight", &"SwingLeft", &"SwingOverhead"] as Array[StringName], "combo clips")


func test_air_slam_holds_its_clips() -> void:
	var made: Array = await _player()
	var player: Player = made[0]
	var pad: ScriptedInputProvider = made[1]
	pad.next.jump_pressed = true
	pad.next.jump_held = true
	await wait_frames(15)
	pad.next.melee_pressed = true
	await wait_frames(2)
	assert_eq(player.fox_model.anim.current_animation, &"SlamRise", "hover")
	assert_true(await wait_until(func() -> bool: return player.fox_model.anim.current_animation == &"SlamFall", 1.0), "plunge")
	assert_true(await wait_until(func() -> bool: return player.fox_model.anim.current_animation == &"SlamLand", 2.0), "impact")


func test_firing_raises_the_gun_arm_and_it_drops_after() -> void:
	var made: Array = await _player()
	var player: Player = made[0]
	var pad: ScriptedInputProvider = made[1]
	assert_eq(player.fox_model.aim_layer.influence, 0.0, "arm down at rest")
	pad.next.fire_held = true
	await wait_seconds(0.3)
	assert_near(player.fox_model.aim_layer.influence, 1.0, 0.01, "arm up while firing")
	# HeldModel rolls guns upright for this frame: mount -Z ahead, mount -X up.
	var mount := player.fox_model.gun_mount.global_basis.orthonormalized()
	var ahead := -player.global_basis.z
	assert_true((mount * Vector3.FORWARD).dot(ahead) > 0.95, "gun mount points ahead")
	assert_true((mount * Vector3.LEFT).dot(Vector3.UP) > 0.95, "gun mount's -X is up")
	pad.next.fire_held = false
	await wait_seconds(player.tuning.fire_facing_time + 0.3)
	assert_eq(player.fox_model.aim_layer.influence, 0.0, "arm back down")


func test_travel_sideways_twists_the_hips_and_backwards_reverses() -> void:
	var fox := _fox()
	# The fox faces -Z; moving toward +X is to its right.
	fox.set_travel(Vector3(FoxModel.WALK_CLIP_SPEED, 0, 0))
	for _i: int in 30:
		fox.update(FoxModel.WALK_CLIP_SPEED, true)
		await wait_frames(1)
	assert_near(absf(fox.twist_layer.yaw), deg_to_rad(FoxModel.TWIST_MAX), 0.05, "hips turned to the side")
	fox.set_travel(Vector3(0, 0, FoxModel.WALK_CLIP_SPEED))
	for _i: int in 30:
		fox.update(FoxModel.WALK_CLIP_SPEED, true)
		await wait_frames(1)
	assert_true(fox.anim.speed_scale < 0.0, "walking backwards plays the walk in reverse")
	assert_near(fox.twist_layer.yaw, 0.0, 0.05, "straight back needs no twist")


func test_glide_holds_its_clip() -> void:
	var made: Array = await _player()
	var player: Player = made[0]
	player.unlock_gadget(&"glide")
	var pad: ScriptedInputProvider = made[1]
	pad.next.jump_pressed = true
	pad.next.jump_held = true
	await wait_frames(10)
	pad.next.jump_pressed = true
	assert_true(await wait_until(func() -> bool: return player.is_gliding(), 2.0), "gliding")
	await wait_frames(2)
	assert_eq(player.fox_model.anim.current_animation, &"Glide", "glide pose")


func test_staff_rides_the_back_and_is_drawn_to_attack() -> void:
	var made: Array = await _player()
	var player: Player = made[0]
	var pad: ScriptedInputProvider = made[1]
	var pivot := player.melee.staff_pivot()
	assert_eq(pivot.get_parent(), player.fox_model.staff_back_mount, "slung on the back at rest")
	assert_true(player._gun.visible, "gun in hand")
	pad.next.melee_pressed = true
	await wait_frames(2)
	assert_eq(pivot.get_parent(), player.fox_model.staff_hand_mount, "drawn for the swing")
	assert_false(player._gun.visible, "gun away while the staff is out")
	var tip := player.melee.staff_pivot().to_global(Vector3(0, 0, StaffMelee.STAFF_TIP_Z))
	assert_near(tip.distance_to(pivot.global_position), -StaffMelee.STAFF_TIP_Z, 0.02, "staff keeps its gameplay length in the hand")
	await wait_until(func() -> bool: return not player.melee.is_busy(), 2.0)
	await wait_frames(2)
	assert_eq(pivot.get_parent(), player.fox_model.staff_back_mount, "stowed again")
	assert_true(player._gun.visible, "gun back")


func test_weapons_with_a_model_hold_it_by_the_grip() -> void:
	var made: Array = await _player()
	var player: Player = made[0]
	for i: int in player.weapons.size():
		var w := player.weapons[i]
		w.owned = true
		player._select_weapon(i)
		await wait_frames(1)
		if w.data.model == null:
			assert_true(player._gun_box.visible, "%s: the box stands in" % w.data.id)
			continue
		assert_false(player._gun_box.visible, "%s: no box" % w.data.id)
		var held := player._gun_models[w.data.id] as Node3D
		assert_true(held.visible, "%s: model shown" % w.data.id)
		var bounds := AABB()
		var first := true
		for mi: MeshInstance3D in held.find_children("*", "MeshInstance3D", true, false):
			var box := held.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		assert_near(bounds.size.z, w.data.model_length, 0.02, "%s: scaled to its length along the barrel" % w.data.id)
		assert_true(bounds.grow(0.02).has_point(Vector3.ZERO), "%s: the grip (origin) is on the model" % w.data.id)
		var turn := (held.get_child(0) as Node3D).basis.orthonormalized()
		assert_true((turn * Vector3.LEFT).is_equal_approx(Vector3.FORWARD), "%s: barrel (model -X) points down the arm (-Z)" % w.data.id)
		assert_true((turn * Vector3.UP).is_equal_approx(Vector3.LEFT), "%s: top up in the aim pose (mount -X)" % w.data.id)


func test_shots_leave_from_the_barrel_tip() -> void:
	var made: Array = await _player()
	var player: Player = made[0]
	for i: int in player.weapons.size():
		var w := player.weapons[i]
		w.owned = true
		player._select_weapon(i)
		player._fire_facing = 10.0
		await wait_frames(20)
		var tip: Vector3
		if w.data.model == null:
			tip = player._gun_box.to_global(Vector3(0, 0, -0.21))
		else:
			tip = ((player._gun_models[w.data.id] as Node3D).get_node(NodePath(HeldModel.TIP)) as Node3D).global_position
		var gap := tip.distance_to(player.muzzle.global_position)
		assert_true(gap < 0.06, "%s: muzzle at the barrel tip (%.2f m off)" % [w.data.id, gap])


func test_firing_kicks_the_gun_back_and_it_settles() -> void:
	var made: Array = await _player()
	var player: Player = made[0]
	var pad: ScriptedInputProvider = made[1]
	var w := player.current_weapon()
	pad.next.fire_held = true
	await wait_frames(2)
	pad.next.fire_held = false
	assert_true(player.recoil > 0.0, "kicked")
	assert_true(player._gun.position.z > 0.0, "slides back up the arm")
	assert_true(player._gun.rotation.y > 0.0, "muzzle tips up")
	var kick := maxf(player.tuning.recoil_min_kick, maxf(w.data.fire_rumble.x, w.data.fire_rumble.y))
	await wait_seconds(kick / player.tuning.recoil_return + 0.1)
	assert_near(player.recoil, 0.0, 0.001, "settled")
	assert_near(player._gun.position.z, 0.0, 0.001, "back in the hand")
