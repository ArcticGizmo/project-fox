extends TestCase
## Ironhorn Sentinel: advances, jab -> hook -> slam (with a Shockwave you jump), then a
## long winded opening. Never flinches.

const SENTINEL := "res://scenes/enemies/ironhorn_sentinel.tscn"
const TIMING_TOLERANCE := 0.04


func test_three_blow_combo_then_winded() -> void:
	add_floor()
	var dummy := add_dummy_target(Vector3.ZERO)
	var s := spawn_enemy(SENTINEL, Vector3(0, 0, -6), PI) as IronhornSentinel
	var winded := await wait_until(func() -> bool: return s.state == &"winded", 8.0)
	assert_true(winded, "finished the combo; log=%s" % [s.state_log])
	var order: Array[String] = ["advance", "jab_windup", "jab", "hook_windup", "hook", "slam_windup", "slam", "winded"]
	var last := -1.0
	for st: String in order:
		var t := state_time_in_log(s.state_log, st)
		assert_true(t > last, "%s in order; log=%s" % [st, s.state_log])
		last = t
	assert_near(state_time_in_log(s.state_log, "jab") - state_time_in_log(s.state_log, "jab_windup"), s.jab_windup, TIMING_TOLERANCE, "jab telegraph")
	assert_near(state_time_in_log(s.state_log, "hook") - state_time_in_log(s.state_log, "hook_windup"), s.hook_windup, TIMING_TOLERANCE, "hook telegraph")
	assert_near(state_time_in_log(s.state_log, "slam") - state_time_in_log(s.state_log, "slam_windup"), s.slam_windup, TIMING_TOLERANCE, "slam telegraph")
	assert_true(dummy.hits.size() >= 1, "a stationary target gets hit")
	assert_near(dummy.hits[0].amount, s.jab_damage, 0.01, "the jab lands first")
	assert_true(s.last_shockwave != null, "the slam sends a ring")
	await wait_seconds(s.winded_time + 0.05)
	assert_true(state_time_in_log(s.state_log, "advance", 1) >= 0.0, "advances again after the opening")


func test_shockwave_is_jumped() -> void:
	add_floor()
	var s := spawn_enemy(SENTINEL, Vector3(0, 0, -2.5), PI) as IronhornSentinel
	s.set_physics_process(false)
	await wait_frames(1)
	s._slam()
	var ring := s.last_shockwave
	var grounded := add_dummy_target(Vector3(4, 0, 0))
	var jumper := add_dummy_target(Vector3(-4, 0, 0))
	jumper.position.y = 1.0
	await wait_seconds(s.shockwave_radius / s.shockwave_speed)
	assert_eq(grounded.hits.size(), 1, "the ring hits feet on the ground")
	assert_near(grounded.damage_taken(), s.shockwave_damage, 0.01, "ring damage")
	assert_eq(jumper.hits.size(), 0, "jumping clears it")
	assert_true(ring == null or not is_instance_valid(ring) or ring.radius > 4.0, "ring passed both")


func test_heavy_never_flinches_and_animates() -> void:
	add_floor()
	add_dummy_target(Vector3.ZERO)
	var s := spawn_enemy(SENTINEL, Vector3(0, 0, -15), PI) as IronhornSentinel
	await wait_seconds(0.5)
	s.hurt_box.receive(DamageInfo.create(5.0, Vector3.ZERO, 10.0))
	assert_true(s.state != Enemy.FLINCH, "no flinch")
	await wait_frames(5)
	assert_eq(s.rig.anim.current_animation, &"Running", "strides when far")
