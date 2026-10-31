extends TestCase
## Enemy awareness: sight (range, cone, line of sight), suspicion, noise,
## damage / point-blank shortcuts, group alerts, leash and wave spawns.
## Enemies here spawn unaware (spawn_enemy(..., aware = false)) unless noted.

const BULL := "res://scenes/enemies/brass_bull.tscn"
const RAT := "res://scenes/enemies/clockwork_rat.tscn"
const FALCON := "res://scenes/enemies/brass_falcon.tscn"
const TIMING_TOLERANCE := 0.06
const GROUP_ALERT_MAX := Enemy.GROUP_ALERT_DELAY_MAX


func before_each() -> void:
	add_floor()


func _placed(path: String, at: Vector3, yaw: float = 0.0, seed_value: int = 1) -> Enemy:
	return spawn_enemy(path, at, yaw, seed_value, false)


func _states(e: Enemy) -> PackedStringArray:
	var out := PackedStringArray()
	for entry: String in e.state_log:
		out.append(entry.split("@")[0])
	return out


func test_out_of_range_stays_at_rest() -> void:
	var bull := _placed(BULL, Vector3.ZERO)
	add_dummy_target(Vector3(0, 0, -(bull.sight_range + 5.0)))
	await wait_seconds(bull.notice_time * 2.0)
	assert_eq(bull.state, Enemy.REST, "still resting; log=%s" % [bull.state_log])
	assert_false(bull.aware, "not aware")
	assert_eq(bull.suspicion, 0.0, "no suspicion")
	assert_false(bull.los_checked, "too far to even look")


func test_notices_in_cone_after_notice_time() -> void:
	var bull := _placed(BULL, Vector3.ZERO)
	add_dummy_target(Vector3(0, 0, -10))
	var alerted := await wait_until(func() -> bool: return bull.state == Enemy.ALERT, bull.notice_time * 3.0)
	assert_true(alerted, "bull noticed the target; log=%s" % [bull.state_log])
	var expected := 1.0 / bull.notice_rate(bull.perceived_distance)
	assert_near(state_time_in_log(bull.state_log, "alert"), expected, TIMING_TOLERANCE, "suspicion filled at notice_rate")
	assert_false(bull.aware, "not aware during the alert pop")
	var aware := await wait_until(func() -> bool: return bull.aware, bull.alert_time + 0.2)
	assert_true(aware, "aware after the alert")
	assert_near(state_time_in_log(bull.state_log, "idle") - state_time_in_log(bull.state_log, "alert"), bull.alert_time, TIMING_TOLERANCE, "alert length")


func test_rest_suspicious_alert_idle_then_combat_sequence() -> void:
	var bull := _placed(BULL, Vector3.ZERO)
	add_dummy_target(Vector3(0, 0, -12))
	var chasing := await wait_until(func() -> bool: return bull.state == &"chase", bull.notice_time * 3.0 + bull.alert_time)
	assert_true(chasing, "bull went on to chase; log=%s" % [bull.state_log])
	var states := _states(bull)
	assert_eq(states.slice(0, 5), PackedStringArray(["rest", "suspicious", "alert", "idle", "chase"]), "awareness sequence")


func test_closer_targets_are_noticed_faster() -> void:
	add_dummy_target(Vector3.ZERO)
	var near := _placed(BULL, Vector3(-3, 0, 4))
	var far := _placed(BULL, Vector3(3, 0, 1.0))
	far.global_position.z = far.sight_range * 0.85
	assert_true(near.notice_rate(4.0) > far.notice_rate(far.sight_range * 0.85), "rate falls with distance")
	var done := await wait_until(func() -> bool: return near.state == Enemy.ALERT or near.aware, far.notice_time * 4.0)
	assert_true(done, "near bull noticed")
	assert_true(not far.aware and far.state != Enemy.ALERT, "far bull still deciding")


func test_chill_slows_suspicion() -> void:
	add_dummy_target(Vector3.ZERO)
	var warm := _placed(BULL, Vector3(-3, 0, 10))
	var cold := _placed(BULL, Vector3(3, 0, 10))
	await wait_frames(1)
	cold.add_chill(0.8, 2.0)
	assert_false(cold.aware, "chill alone does not wake it")
	await wait_seconds(0.6)
	assert_true(cold.suspicion < warm.suspicion, "chilled suspicion fills slower (%.2f vs %.2f)" % [cold.suspicion, warm.suspicion])


func test_behind_a_block_never_notices() -> void:
	var bull := _placed(BULL, Vector3.ZERO)
	add_dummy_target(Vector3(0, 0, -10))
	add_wall(Vector3(0, 2, -5), Vector3(6, 4, 1))
	await wait_seconds(bull.notice_time * 3.0)
	assert_eq(bull.state, Enemy.REST, "still resting; log=%s" % [bull.state_log])
	assert_eq(bull.suspicion, 0.0, "no suspicion")
	assert_true(bull.los_checked and bull.los_blocked, "line of sight ray was blocked")


func test_out_of_cone_unseen_but_noise_sends_it_to_investigate() -> void:
	var bull := _placed(BULL, Vector3.ZERO)
	var dummy := add_dummy_target(Vector3(0, 0, 8))
	await wait_seconds(bull.notice_time * 2.0)
	assert_eq(bull.state, Enemy.REST, "target behind is not seen; log=%s" % [bull.state_log])
	assert_eq(bull.suspicion, 0.0, "no suspicion from behind")
	var far_radius := maxf(0.0, 50.0 - bull.hearing_range - 1.0)
	assert_eq(NoiseEvent.emit(Vector3(0, 0, 50), far_radius, self), 0, "out-of-earshot noise unheard")
	assert_eq(bull.state, Enemy.REST, "ignores a noise out of earshot")
	var heard := NoiseEvent.emit(dummy.global_position, 4.0, self)
	assert_eq(heard, 1, "one enemy heard the noise")
	assert_eq(bull.state, Enemy.INVESTIGATE, "goes to investigate")
	assert_true(bull.investigate_point.is_equal_approx(dummy.global_position), "investigates the noise point")
	assert_false(NoiseEvent.recent_emits().is_empty(), "emits are recorded for the debug view")
	var spotted := await wait_until(func() -> bool: return bull.state == Enemy.SUSPICIOUS or bull.state == Enemy.ALERT, 4.0)
	assert_true(spotted, "turning to investigate, it spots the target; log=%s" % [bull.state_log])


func test_hit_makes_it_aware_at_once() -> void:
	var bull := _placed(BULL, Vector3.ZERO)
	add_dummy_target(Vector3(0, 0, 15))
	await wait_frames(2)
	bull.hurt_box.receive(DamageInfo.create(5.0, Vector3(0, 0, 15)))
	assert_true(bull.aware, "aware the moment it is hit")
	assert_false("alert" in _states(bull), "no alert pop; log=%s" % [bull.state_log])
	await wait_frames(2)
	assert_eq(bull.state, &"chase", "straight into combat")


func test_hazard_damage_does_not_wake() -> void:
	var bull := _placed(BULL, Vector3.ZERO)
	await wait_frames(2)
	var info := DamageInfo.create(5.0, Vector3(0, 0, 2))
	info.from_hazard = true
	bull.hurt_box.receive(info)
	assert_false(bull.aware, "hazards are neutral")


func test_point_blank_notices_at_once_from_behind() -> void:
	var bull := _placed(BULL, Vector3.ZERO)
	add_dummy_target(Vector3(0, 0, bull.extents().z * 0.5 + 1.2))
	await wait_frames(3)
	assert_true(bull.aware, "point-blank target noticed; log=%s" % [bull.state_log])
	assert_false("alert" in _states(bull), "no alert pop")


func test_group_alert_reaches_neighbour_in_radius_without_chaining() -> void:
	var alerter := _placed(BULL, Vector3.ZERO, 0.0, 1)
	var r := alerter.alert_radius
	# Neighbours face away (+Z) so only the alert can wake them.
	var near := _placed(BULL, Vector3(r * 0.6, 0, 0), PI, 2)
	var chained := _placed(BULL, Vector3(r * 1.4, 0, 0), PI, 3)
	var walled := _placed(BULL, Vector3(-r * 0.6, 0, 0), PI, 4)
	add_wall(Vector3(-r * 0.3, 2, 0), Vector3(1, 4, 6))
	add_dummy_target(Vector3(0, 0, -10))
	var woke := await wait_until(func() -> bool: return near.aware, alerter.notice_time * 3.0 + GROUP_ALERT_MAX + near.alert_time + 0.5)
	assert_true(woke, "neighbour in radius woke; log=%s" % [near.state_log])
	assert_eq(near.alerted_by, alerter, "woken by the alerter")
	var delay := state_time_in_log(near.state_log, "alert") - state_time_in_log(alerter.state_log, "alert")
	assert_true(delay >= Enemy.GROUP_ALERT_DELAY_MIN - 0.02 and delay <= Enemy.GROUP_ALERT_DELAY_MAX + 0.04, "staggered delay %.2f" % delay)
	await wait_seconds(1.0)
	assert_false(chained.aware or chained.is_alert_pending(), "alerts do not chain; log=%s" % [chained.state_log])
	assert_false(walled.aware or walled.is_alert_pending(), "no alert through a wall; log=%s" % [walled.state_log])


func test_leash_returns_home_heals_and_goes_unaware() -> void:
	var bull := _placed(BULL, Vector3.ZERO)
	bull.leash_radius = 6.0
	add_dummy_target(Vector3(0, 0, -30))
	await wait_frames(2)
	bull.hurt_box.receive(DamageInfo.create(20.0, Vector3(0, 0, -30)))
	assert_true(bull.aware, "hit wakes it")
	var leashed := await wait_until(func() -> bool: return bull.state == Enemy.RETURN_HOME, 6.0)
	assert_true(leashed, "gave up at the leash; log=%s" % [bull.state_log])
	assert_false(bull.aware, "unaware while heading home")
	var home := await wait_until(func() -> bool: return bull.state == Enemy.REST, bull.leash_radius / (bull.move_speed * Enemy.RETURN_SPEED_FACTOR) + 4.0)
	assert_true(home, "walked home; log=%s" % [bull.state_log])
	assert_true(Enemy._flat_distance(bull.global_position, bull.home_position) <= Enemy.ARRIVE_DISTANCE + 0.1, "back at home")
	assert_eq(bull.health.current, bull.health.max_health, "healed at home")


func test_wave_spawned_enemies_start_aware() -> void:
	var waves := WaveManager.new()
	add_child(waves)
	var rat := waves.spawn_enemy(&"rat", Vector3(0, 0, -5))
	var placed := _placed(RAT, Vector3(5, 0, -5))
	await wait_frames(1)
	assert_true(rat.aware, "wave enemy starts aware")
	assert_true(rat.state_log[0].begins_with("idle@"), "starts in idle; log=%s" % [rat.state_log])
	assert_eq(rat.leash_radius, 0.0, "wave enemies have no leash")
	assert_false(placed.aware, "placed enemy starts unaware")
	assert_true(placed.state_log[0].begins_with("rest@"), "placed starts at rest; log=%s" % [placed.state_log])


func test_unaware_flyer_hovers_over_home() -> void:
	var falcon := _placed(FALCON, Vector3.ZERO)
	await wait_seconds(3.0)
	assert_false(falcon.aware, "nothing to notice")
	assert_true(falcon.altitude() >= falcon.hover_height * 0.8, "cruises at height (%.1fm)" % falcon.altitude())
	assert_true(Enemy._flat_distance(falcon.global_position, falcon.home_position) < 1.0, "stays over home")


func test_rat_wanders_near_home() -> void:
	var rat := _placed(RAT, Vector3.ZERO)
	var wandered := await wait_until(func() -> bool: return rat.state == Enemy.WANDER, rat.rest_time_max + 0.2)
	assert_true(wandered, "rat set off wandering; log=%s" % [rat.state_log])
	var max_dist := 0.0
	for _i: int in 240:
		await wait_frames(1)
		max_dist = maxf(max_dist, Enemy._flat_distance(rat.global_position, rat.home_position))
	assert_true(max_dist > 0.3, "moved (%.2fm)" % max_dist)
	assert_true(max_dist <= rat.wander_radius + 0.5, "stays within wander_radius (%.2fm)" % max_dist)
