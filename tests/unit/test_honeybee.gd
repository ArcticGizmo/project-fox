extends TestCase
## Clockwork Honeybee: hovers low round the target, winds up, darts through it; a swarm
## takes turns; hits flinch it out of the windup.

const BEE := "res://scenes/enemies/clockwork_honeybee.tscn"
const TIMING_TOLERANCE := 0.04


func test_hovers_low_then_stings_the_target() -> void:
	add_floor()
	var dummy := add_dummy_target(Vector3.ZERO)
	var bee := spawn_enemy(BEE, Vector3(0, 2, -8), PI) as ClockworkHoneybee
	assert_true(bee.model != null, "wears its model")
	var stung := await wait_until(func() -> bool: return bee.state == &"recover", 6.0)
	assert_true(stung, "stung; log=%s" % [bee.state_log])
	var order: Array[String] = ["hover", "windup", "sting", "recover"]
	var last := -1.0
	for s: String in order:
		var t := state_time_in_log(bee.state_log, s)
		assert_true(t > last, "%s in order; log=%s" % [s, bee.state_log])
		last = t
	assert_near(state_time_in_log(bee.state_log, "sting") - state_time_in_log(bee.state_log, "windup"),
			bee.windup_time, TIMING_TOLERANCE, "windup telegraph length")
	assert_eq(dummy.hits.size(), 1, "one sting")
	assert_near(dummy.damage_taken(), bee.sting_damage, 0.01, "sting damage")
	await wait_seconds(bee.recover_time + 1.0)
	assert_true(bee.altitude() > 1.2 and bee.altitude() < bee.hover_height + bee.bob_height + 0.6,
			"back to a low hover (%.1fm)" % bee.altitude())


func test_swarm_takes_turns() -> void:
	add_floor()
	add_dummy_target(Vector3.ZERO)
	var bees: Array[ClockworkHoneybee] = []
	for i: int in 4:
		var a := TAU * i / 4.0
		bees.append(spawn_enemy(BEE, Vector3(sin(a), 0.4, cos(a)) * 6.0 + Vector3.UP * 2.0, a, i + 1) as ClockworkHoneybee)
	var most := 0
	var stings := 0
	for _f: int in 60 * 8:
		await get_tree().physics_frame
		var now := 0
		for b: ClockworkHoneybee in bees:
			if b.is_attacking():
				now += 1
		most = maxi(most, now)
	for b: ClockworkHoneybee in bees:
		if state_time_in_log(b.state_log, "sting") >= 0.0:
			stings += 1
	assert_eq(most, 1, "never two at once")
	assert_true(stings >= 3, "most of the swarm got a turn (%d)" % stings)


func test_hit_flinches_it_out_of_the_windup() -> void:
	add_floor()
	var dummy := add_dummy_target(Vector3.ZERO)
	var bee := spawn_enemy(BEE, Vector3(0, 2, -6), PI) as ClockworkHoneybee
	var winding := await wait_until(func() -> bool: return bee.state == &"windup", 5.0)
	assert_true(winding, "winding up")
	bee.hurt_box.receive(DamageInfo.create(1.0, dummy.global_position))
	assert_eq(bee.state, Enemy.FLINCH, "flinched")
	await wait_seconds(bee.flinch_time + 0.1)
	assert_eq(bee.state, &"hover", "back to hovering")
	assert_eq(dummy.hits.size(), 0, "no sting")
