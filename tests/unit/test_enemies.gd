extends TestCase
## Attack-pattern tests: each enemy's state sequence and timings, verified
## frame-by-frame against a stationary dummy target.

const BULL := "res://scenes/enemies/brass_bull.tscn"
const RAT := "res://scenes/enemies/clockwork_rat.tscn"
const TOAD := "res://scenes/enemies/spitter_toad.tscn"
const FALCON := "res://scenes/enemies/brass_falcon.tscn"
const GULL := "res://scenes/enemies/bombardier_gull.tscn"
const PANGOLIN := "res://scenes/enemies/brass_pangolin.tscn"
const TIMING_TOLERANCE := 0.04


func _durations(e: Enemy, from_state: String, to_state: String) -> float:
	return state_time_in_log(e.state_log, to_state) - state_time_in_log(e.state_log, from_state)


func test_enemy_sizes_match_body_size() -> void:
	add_floor()
	for path: String in [BULL, RAT, TOAD, FALCON, GULL, PANGOLIN]:
		var e := spawn_enemy(path, Vector3.ZERO)
		await wait_frames(1)
		var ext := e.extents()
		assert_true(ext.x > 0.2 and ext.y > 0.2 and ext.z > 0.2, "%s has a sensible size %s" % [e.display_name, ext])
		assert_near(e.get_aim_point().y - e.global_position.y, ext.y * 0.5, 0.01, "%s aim point at half height" % e.display_name)
		var hcs := e.hurt_box.get_child(0) as CollisionShape3D
		assert_near(hcs.position.y, ext.y * 0.5, 0.01, "%s hurtbox centred on body" % e.display_name)
		e.queue_free()
		await wait_frames(1)


func test_bull_charge_pattern() -> void:
	add_floor()
	var dummy := add_dummy_target(Vector3.ZERO)
	var bull := spawn_enemy(BULL, Vector3(0, 0, -12), PI) as BrassBull
	var reached := await wait_until(func() -> bool: return bull.state == &"recover", 5.0)
	assert_true(reached, "bull reached recover; log=%s" % [bull.state_log])
	var chase := state_time_in_log(bull.state_log, "chase")
	var windup := state_time_in_log(bull.state_log, "windup")
	var charge := state_time_in_log(bull.state_log, "charge")
	assert_true(chase >= 0.0 and windup > chase and charge > windup, "chase -> windup -> charge; log=%s" % [bull.state_log])
	assert_near(charge - windup, bull.windup_time, TIMING_TOLERANCE, "windup telegraph length")
	assert_eq(dummy.hits.size(), 1, "charge hits exactly once")
	assert_near(dummy.damage_taken(), bull.charge_damage, 0.01, "charge damage")


func test_bull_stuns_on_wall() -> void:
	add_floor()
	var dummy := add_dummy_target(Vector3.ZERO)
	add_wall(Vector3(0, 1.5, -4), Vector3(12, 3, 1))
	var bull := spawn_enemy(BULL, Vector3(0, 0, -14), PI) as BrassBull
	var stunned := await wait_until(func() -> bool: return bull.state == &"stunned", 5.0)
	assert_true(stunned, "bull stunned itself on the wall; log=%s" % [bull.state_log])
	assert_eq(dummy.hits.size(), 0, "dummy behind wall untouched")


func test_bull_weak_spot_takes_bonus_damage() -> void:
	add_floor()
	var bull := spawn_enemy(BULL, Vector3.ZERO) as BrassBull
	await wait_frames(1)
	var info := DamageInfo.create(10.0, Vector3.UP * 5.0)
	assert_true(bull.weak_spot.receive(info), "weak spot accepts hit")
	assert_true(info.is_critical, "marked critical")
	assert_near(bull.health.max_health - bull.health.current, 10.0 * bull.weak_spot_multiplier, 0.01, "multiplied")


func test_rat_orbit_then_lunge_pattern() -> void:
	add_floor()
	var dummy := add_dummy_target(Vector3.ZERO)
	var rat := spawn_enemy(RAT, Vector3(0, 0, -9), PI) as ClockworkRat
	var done := await wait_until(func() -> bool: return rat.state == &"recover", 6.0)
	assert_true(done, "rat lunged and recovered; log=%s" % [rat.state_log])
	var order: Array[String] = ["approach", "orbit", "windup", "lunge", "recover"]
	var last := -1.0
	for s: String in order:
		var t := state_time_in_log(rat.state_log, s)
		assert_true(t > last, "%s after previous state; log=%s" % [s, rat.state_log])
		last = t
	assert_near(_durations(rat, "windup", "lunge"), rat.lunge_windup, TIMING_TOLERANCE, "lunge telegraph length")
	assert_near(_durations(rat, "lunge", "recover"), rat.lunge_time, TIMING_TOLERANCE, "lunge length")
	assert_eq(dummy.hits.size(), 1, "lunge bites stationary target once")


func test_rat_flinches_out_of_windup() -> void:
	add_floor()
	add_dummy_target(Vector3.ZERO)
	var rat := spawn_enemy(RAT, Vector3(0, 0, -9), PI) as ClockworkRat
	var winding := await wait_until(func() -> bool: return rat.state == &"windup", 6.0)
	assert_true(winding, "rat started a windup")
	rat.hurt_box.receive(DamageInfo.create(1.0, Vector3.ZERO))
	assert_eq(rat.state, Enemy.FLINCH, "damage interrupts windup")
	await wait_seconds(rat.flinch_time + 0.05)
	var flinch_at := rat.state_log.find("%s@" % Enemy.FLINCH)
	var after := ""
	for i: int in rat.state_log.size():
		if rat.state_log[i].begins_with("flinch@") and i + 1 < rat.state_log.size():
			after = rat.state_log[i + 1].split("@")[0]
	assert_eq(after, "approach", "resumes approach after flinch; log=%s" % [rat.state_log])


func test_toad_backs_off_then_lobs_onto_target() -> void:
	add_floor()
	var dummy := add_dummy_target(Vector3.ZERO)
	var toad := spawn_enemy(TOAD, Vector3(0, 0, -5), PI) as SpitterToad
	await wait_seconds(1.5)
	assert_true(toad.distance_to_target() > 6.5, "toad retreats from close range (%.1fm)" % toad.distance_to_target())
	var fired := await wait_until(func() -> bool: return toad.attack_count > 0, 4.0)
	assert_true(fired, "toad attacked; log=%s" % [toad.state_log])
	assert_near(_durations(toad, "windup", "recover"), toad.windup_time, TIMING_TOLERANCE, "inflate telegraph length")
	var landed := await wait_until(func() -> bool: return dummy.hits.size() > 0, toad.lob_flight_time + 0.2)
	assert_true(landed, "glob landed on stationary target")
	assert_near(dummy.damage_taken(), toad.lob_damage, 0.01, "lob damage")


func test_toad_leads_moving_target_and_volleys() -> void:
	add_floor()
	var dummy := add_dummy_target(Vector3.ZERO)
	var toad := spawn_enemy(TOAD, Vector3(0, 0, -12), PI) as SpitterToad
	await wait_frames(2)
	dummy.velocity = Vector3(5, 0, 0)
	var p := toad.predicted_target_point()
	assert_near(p.x, 5.0 * toad.lob_flight_time * toad.lead_factor, 0.01, "leads along velocity")
	assert_false(toad.is_volley_attack(0), "1st single")
	assert_false(toad.is_volley_attack(1), "2nd single")
	assert_true(toad.is_volley_attack(2), "3rd is a volley")
