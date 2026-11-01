extends TestCase


func _fox() -> FoxModel:
	var fox := FoxModel.new(Player.HEIGHT)
	add_child(fox)
	return fox


func test_clips_are_baked_and_loop() -> void:
	var fox := _fox()
	for clip: StringName in [&"Idle", &"Walk", &"Running"]:
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
	fox.update(8.0, false)
	assert_eq(fox.anim.current_animation, &"Idle", "airborne")
