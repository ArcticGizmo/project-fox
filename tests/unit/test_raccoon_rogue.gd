extends TestCase
## Raccoon Rogue: darts in, telegraphs, swipes; a landed swipe steals glimmer and it
## flees, shedding loot when hit; caught it spills the lot, otherwise it escapes.

const ROGUE := "res://scenes/enemies/raccoon_rogue.tscn"
const TIMING_TOLERANCE := 0.04


func _loose_glimmer() -> int:
	var total := 0
	for n: Node in get_tree().get_nodes_in_group(Glimmer.GROUP):
		total += (n as Glimmer).value
	return total


func test_rigged_model_plays_the_fox_clips() -> void:
	add_floor()
	var rogue := spawn_enemy(ROGUE, Vector3.ZERO) as RaccoonRogue
	await wait_frames(1)
	assert_true(rogue.rig != null and rogue.model == rogue.rig, "the rig is its model")
	for clip: StringName in [&"Idle", &"Walk", &"Running", &"SwingRight", &"Hurt"]:
		assert_true(rogue.rig.anim.has_animation(clip), "has %s" % clip)
	assert_false(rogue._model_materials.is_empty(), "rig material claimed for glows")


func test_swipe_steals_glimmer_then_flees() -> void:
	add_floor()
	var dummy := add_dummy_target(Vector3.ZERO)
	dummy.glimmer = 100
	var rogue := spawn_enemy(ROGUE, Vector3(0, 0, -9), PI) as RaccoonRogue
	var fled := await wait_until(func() -> bool: return rogue.state == &"flee", 5.0)
	assert_true(fled, "stole and fled; log=%s" % [rogue.state_log])
	var order: Array[String] = ["dart", "snatch_windup", "snatch", "flee"]
	var last := -1.0
	for s: String in order:
		var t := state_time_in_log(rogue.state_log, s)
		assert_true(t > last, "%s in order; log=%s" % [s, rogue.state_log])
		last = t
	assert_near(state_time_in_log(rogue.state_log, "snatch") - state_time_in_log(rogue.state_log, "snatch_windup"),
			rogue.snatch_windup, TIMING_TOLERANCE, "snatch telegraph length")
	assert_eq(rogue.loot, rogue.steal_amount, "carries the loot")
	assert_eq(dummy.glimmer, 100 - rogue.steal_amount, "taken from the target")
	assert_near(dummy.damage_taken(), rogue.snatch_damage, 0.01, "swipe damage")
	var d0 := rogue.distance_to_target()
	await wait_seconds(0.6)
	assert_true(rogue.distance_to_target() > d0 + 2.0, "runs away")
	assert_eq(rogue.rig.anim.current_animation, &"Running", "running clip while fleeing")


func test_empty_pockets_swipe_then_dart_again() -> void:
	add_floor()
	var dummy := add_dummy_target(Vector3.ZERO)
	var rogue := spawn_enemy(ROGUE, Vector3(0, 0, -9), PI) as RaccoonRogue
	var again := await wait_until(func() -> bool: return state_time_in_log(rogue.state_log, "dart", 1) >= 0.0, 6.0)
	assert_true(again, "darted in again; log=%s" % [rogue.state_log])
	assert_true(state_time_in_log(rogue.state_log, "recover") >= 0.0, "recovered after the swipe")
	assert_eq(state_time_in_log(rogue.state_log, "flee"), -1.0, "nothing to steal, no flight")
	assert_eq(dummy.hits.size(), 1, "the swipe still hurts")


func test_hits_shed_loot_and_a_kill_spills_the_rest() -> void:
	add_floor()
	var dummy := add_dummy_target(Vector3.ZERO)
	dummy.glimmer = 100
	var rogue := spawn_enemy(ROGUE, Vector3(0, 0, -9), PI) as RaccoonRogue
	await wait_until(func() -> bool: return rogue.state == &"flee", 5.0)
	rogue.hurt_box.receive(DamageInfo.create(1.0, dummy.global_position))
	assert_eq(rogue.state, &"flee", "a hit doesn't stop the flight")
	assert_eq(rogue.loot, rogue.steal_amount - rogue.drop_per_hit, "shed some")
	assert_eq(_loose_glimmer(), rogue.drop_per_hit, "spilled what it shed")
	var own := rogue.xp_value * Enemy.GLIMMER_PER_XP
	var left := rogue.loot
	rogue.hurt_box.receive(DamageInfo.create(1000.0, dummy.global_position))
	await wait_frames(1)
	assert_eq(_loose_glimmer(), rogue.drop_per_hit + left + own, "the kill spills its loot and its own glimmer")


func test_escapes_with_the_loot() -> void:
	add_floor()
	var dummy := add_dummy_target(Vector3.ZERO)
	dummy.glimmer = 100
	var rogue := spawn_enemy(ROGUE, Vector3(0, 0, -9), PI) as RaccoonRogue
	rogue.escape_time = 1.0
	var rogue_steal := rogue.steal_amount
	await wait_until(func() -> bool: return rogue.state == &"flee", 5.0)
	var ref: WeakRef = weakref(rogue)
	var gone := await wait_until(func() -> bool: return ref.get_ref() == null, rogue.escape_distance / rogue.flee_speed + 2.0)
	assert_true(gone, "vanished")
	assert_eq(_loose_glimmer(), 0, "took the loot along")
	assert_eq(dummy.glimmer, 100 - rogue_steal, "the target stays robbed")
