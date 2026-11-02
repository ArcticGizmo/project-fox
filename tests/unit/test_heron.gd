extends TestCase
## Chime Heron: shields allies in range, drops it when disabled or dead, keeps
## its distance, pecks when cornered.

const HERON := "res://scenes/enemies/chime_heron.tscn"
const BULL := "res://scenes/enemies/brass_bull.tscn"


func _hit(e: Enemy, amount: float = 20.0) -> float:
	var before := e.health.current
	e.hurt_box.receive(DamageInfo.create(amount, e.global_position + Vector3(0, 1, 6)))
	return before - e.health.current


func test_shields_allies_in_range_only() -> void:
	add_floor()
	var heron := spawn_enemy(HERON, Vector3.ZERO) as ChimeHeron
	var near := spawn_enemy(BULL, Vector3(4, 0, 0))
	var far := spawn_enemy(BULL, Vector3(heron.shield_radius + 6.0, 0, 0))
	await wait_frames(3)
	assert_true(near.is_shielded(), "ally in range shielded")
	assert_false(far.is_shielded(), "ally out of range not")
	assert_false(heron.is_shielded(), "the heron does not shield itself")
	assert_true(heron.covered.has(near) and not heron.covered.has(far), "covered list")
	assert_near(_hit(near), 20.0 * Enemy.SHIELDED_DAMAGE_MULTIPLIER, 0.01, "shielded damage")
	assert_near(_hit(far), 20.0, 0.01, "unshielded damage")
	assert_near(_hit(heron), 20.0, 0.01, "the heron itself takes full damage")


func test_shield_drops_when_staggered_or_killed() -> void:
	add_floor()
	var heron := spawn_enemy(HERON, Vector3.ZERO) as ChimeHeron
	var bull := spawn_enemy(BULL, Vector3(4, 0, 0))
	await wait_frames(3)
	assert_true(bull.is_shielded(), "shielded")
	heron.stagger(1.0)
	await wait_seconds(heron.shield_hold + 0.1)
	assert_false(heron.is_shielding(), "staggered heron is silent")
	assert_false(bull.is_shielded(), "shield lapses")
	var back := await wait_until(func() -> bool: return bull.is_shielded(), 2.0)
	assert_true(back, "shield returns after the stagger")
	heron.health.apply_damage(DamageInfo.create(1000.0, Vector3.ZERO))
	await wait_seconds(heron.shield_hold + 0.1)
	assert_false(bull.is_shielded(), "shield gone with the heron")


func test_shielded_hits_clank() -> void:
	add_floor()
	spawn_enemy(HERON, Vector3.ZERO)
	var bull := spawn_enemy(BULL, Vector3(4, 0, 0))
	await wait_frames(3)
	Sfx.reset()
	_hit(bull)
	assert_true(Sfx.played(&"clank"), "shielded hit clanks")


func test_keeps_its_distance() -> void:
	add_floor()
	add_dummy_target(Vector3.ZERO)
	var heron := spawn_enemy(HERON, Vector3(0, 0, -5), PI) as ChimeHeron
	await wait_seconds(2.0)
	assert_true(heron.distance_to_target() >= heron.keep_away_min - 0.5, "backed off to %.1f m" % heron.distance_to_target())


func test_pecks_when_cornered() -> void:
	add_floor()
	var dummy := add_dummy_target(Vector3.ZERO)
	var heron := spawn_enemy(HERON, Vector3(0, 0, -1.8), PI) as ChimeHeron
	heron.keep_away_min = 0.0  # stand its ground for the test
	var pecked := await wait_until(func() -> bool: return heron.state == &"recover", 3.0)
	assert_true(pecked, "pecked; log=%s" % [heron.state_log])
	var windup := state_time_in_log(heron.state_log, "peck_windup")
	var peck := state_time_in_log(heron.state_log, "peck")
	assert_near(peck - windup, heron.peck_windup_time, 0.04, "peck telegraph")
	assert_eq(dummy.hits.size(), 1, "one peck lands")
	assert_near(dummy.damage_taken(), heron.peck_damage, 0.01, "peck damage")
