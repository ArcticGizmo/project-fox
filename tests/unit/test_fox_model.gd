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
