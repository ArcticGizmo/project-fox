extends TestCase
## Flying enemies: the diving Brass Falcon and the bomb-lobbing Bombardier Gull,
## plus the shared flight rules (hover height, frozen flyers fall).

const FALCON := "res://scenes/enemies/brass_falcon.tscn"
const GULL := "res://scenes/enemies/bombardier_gull.tscn"
const TIMING_TOLERANCE := 0.04


func before_each() -> void:
	add_floor()


func test_falcon_circles_at_height_then_dives_onto_target() -> void:
	var dummy := add_dummy_target(Vector3.ZERO)
	var falcon := spawn_enemy(FALCON, Vector3(0, 0, -8), PI) as BrassFalcon
	var winding := await wait_until(func() -> bool: return falcon.state == &"windup", 6.0)
	assert_true(winding, "falcon started a dive windup; log=%s" % [falcon.state_log])
	assert_true(falcon.altitude() >= falcon.hover_height * 0.7, "winds up from altitude (%.1fm)" % falcon.altitude())
	var done := await wait_until(func() -> bool: return falcon.state == &"recover" or falcon.state == &"grounded", 3.0)
	assert_true(done, "dive finished; log=%s" % [falcon.state_log])
	var circle := state_time_in_log(falcon.state_log, "circle")
	var windup := state_time_in_log(falcon.state_log, "windup")
	var dive := state_time_in_log(falcon.state_log, "dive")
	assert_true(circle >= 0.0 and windup > circle and dive > windup, "circle -> windup -> dive; log=%s" % [falcon.state_log])
	assert_near(dive - windup, falcon.windup_time, TIMING_TOLERANCE, "dive telegraph length")
	assert_eq(falcon.state, &"recover", "pulls out after a hit")
	assert_eq(dummy.hits.size(), 1, "dive hits exactly once")
	assert_near(dummy.damage_taken(), falcon.dive_damage, 0.01, "dive damage")


func test_dodged_dive_grounds_the_falcon_then_it_climbs_back() -> void:
	var dummy := add_dummy_target(Vector3.ZERO)
	var falcon := spawn_enemy(FALCON, Vector3(0, 0, -8), PI) as BrassFalcon
	var diving := await wait_until(func() -> bool: return falcon.state == &"dive", 7.0)
	assert_true(diving, "falcon dived; log=%s" % [falcon.state_log])
	dummy.global_position = Vector3(7, 0, 0)
	var grounded := await wait_until(func() -> bool: return falcon.state == &"grounded", 2.0)
	assert_true(grounded, "missed dive ploughs into the ground; log=%s" % [falcon.state_log])
	assert_eq(dummy.hits.size(), 0, "sidestepped target untouched")
	assert_true(falcon.altitude() < 0.3, "grounded within staff reach (%.2fm)" % falcon.altitude())
	await wait_seconds(falcon.grounded_time + 1.0)
	assert_true(falcon.altitude() > 2.0, "climbs back up after recovering (%.2fm)" % falcon.altitude())


func test_frozen_flyer_drops_then_climbs_after_thaw() -> void:
	add_dummy_target(Vector3.ZERO)
	var gull := spawn_enemy(GULL, Vector3(0, 0, -10), PI) as BombardierGull
	var up := await wait_until(func() -> bool: return gull.altitude() > gull.hover_height * 0.8, 4.0)
	assert_true(up, "gull reached cruising height")
	gull.freeze(1.5)
	await wait_seconds(1.0)
	assert_true(gull.is_frozen(), "still frozen")
	assert_true(gull.altitude() < 0.2, "frozen flyer fell to the ground (%.2fm)" % gull.altitude())
	await wait_seconds(1.5)
	assert_true(gull.altitude() > 1.5, "flies again after thawing (%.2fm)" % gull.altitude())


func test_gull_holds_range_at_height_and_bombs_target() -> void:
	var dummy := add_dummy_target(Vector3.ZERO)
	var gull := spawn_enemy(GULL, Vector3(0, 0, -4), PI) as BombardierGull
	await wait_seconds(1.5)
	assert_true(gull.distance_to_target() > 5.0, "backs off from close range (%.1fm)" % gull.distance_to_target())
	assert_true(gull.altitude() > 3.0, "climbs while repositioning (%.1fm)" % gull.altitude())
	var fired := await wait_until(func() -> bool: return gull.attack_count > 0, 4.0)
	assert_true(fired, "gull attacked; log=%s" % [gull.state_log])
	assert_near(_durations(gull, "windup", "recover"), gull.windup_time, TIMING_TOLERANCE, "puff-up telegraph length")
	var landed := await wait_until(func() -> bool: return dummy.hits.size() > 0, gull.lob_flight_time + 0.2)
	assert_true(landed, "bomb landed on stationary target")
	assert_near(dummy.damage_taken(), gull.lob_damage, 0.01, "bomb damage")


func test_gull_barrage_walks_along_the_approach_line() -> void:
	add_dummy_target(Vector3.ZERO)
	var gull := spawn_enemy(GULL, Vector3(0, 0, -10), PI) as BombardierGull
	await wait_frames(2)
	assert_false(gull.is_barrage_attack(0), "1st single")
	assert_true(gull.is_barrage_attack(gull.barrage_every - 1), "every Nth is a barrage")
	assert_eq(gull.bomb_points(0).size(), 1, "single bomb")
	var points := gull.bomb_points(gull.barrage_every - 1)
	assert_eq(points.size(), gull.barrage_count, "barrage bomb count")
	for i: int in points.size():
		assert_near(points[i].x, 0.0, 0.01, "bomb %d on the approach line" % i)
		var expected := gull.barrage_spacing * (float(i) - (gull.barrage_count - 1) * 0.5)
		assert_near(points[i].z, expected, 0.01, "bomb %d walks near to far" % i)


func _durations(e: Enemy, from_state: String, to_state: String) -> float:
	return state_time_in_log(e.state_log, to_state) - state_time_in_log(e.state_log, from_state)
