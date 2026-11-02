extends TestCase
## Brass Pangolin: frontal armour, shard volley, curl-and-roll, dizzy belly.

const PANGOLIN := "res://scenes/enemies/brass_pangolin.tscn"
const TIMING_TOLERANCE := 0.04


func _hit(p: BrassPangolin, hb: HurtBox, from: Vector3, amount: float = 10.0) -> float:
	var before := p.health.current
	hb.receive(DamageInfo.create(amount, from))
	return before - p.health.current


func test_armour_turns_aside_frontal_hits_only() -> void:
	add_floor()
	var p := spawn_enemy(PANGOLIN, Vector3.ZERO, 0.0, 1, false) as BrassPangolin
	await wait_frames(1)
	var front := p.global_position + p.forward() * 4.0
	var back := p.global_position - p.forward() * 4.0
	var side := p.global_position + p.forward().cross(Vector3.UP) * 4.0
	assert_near(_hit(p, p.hurt_box, front), 10.0 * p.armour_factor, 0.01, "front hit blocked")
	assert_near(_hit(p, p.hurt_box, back), 10.0, 0.01, "rear hit full")
	assert_near(_hit(p, p.hurt_box, side), 10.0, 0.01, "flank hit full (outside the guard arc)")
	assert_eq(p.blocked_hits, 1, "one blocked hit counted")


func test_explosion_behind_ignores_armour() -> void:
	add_floor()
	var p := spawn_enemy(PANGOLIN, Vector3.ZERO, 0.0, 1, false) as BrassPangolin
	await wait_frames(2)
	var behind := p.get_aim_point() - p.forward() * 1.5
	Explosion.detonate(self, behind, 2.5, Layers.ENEMY_HURTBOX, func() -> DamageInfo: return DamageInfo.create(20.0, behind))
	assert_near(p.health.max_health - p.health.current, 20.0, 0.01, "blast from behind lands in full")
	var before := p.health.current
	var ahead := p.get_aim_point() + p.forward() * 1.8
	Explosion.detonate(self, ahead, 2.5, Layers.ENEMY_HURTBOX, func() -> DamageInfo: return DamageInfo.create(20.0, ahead))
	assert_near(before - p.health.current, 20.0 * p.armour_factor, 0.01, "blast in front is blocked")


func test_stagger_drops_the_guard() -> void:
	add_floor()
	var p := spawn_enemy(PANGOLIN, Vector3.ZERO) as BrassPangolin
	await wait_frames(1)
	p.stagger(1.0)
	assert_false(p.is_guarding(), "staggered pangolin is open")
	assert_near(_hit(p, p.hurt_box, p.global_position + p.forward() * 4.0), 10.0, 0.01, "front hit lands while staggered")


func test_volley_pattern_fans_shards() -> void:
	add_floor()
	var dummy := add_dummy_target(Vector3.ZERO)
	var p := spawn_enemy(PANGOLIN, Vector3(0, 0, -11), PI) as BrassPangolin
	var reached := await wait_until(func() -> bool: return p.state == &"volley_recover", 6.0)
	assert_true(reached, "pangolin volleyed; log=%s" % [p.state_log])
	var advance := state_time_in_log(p.state_log, "advance")
	var windup := state_time_in_log(p.state_log, "volley_windup")
	var recover := state_time_in_log(p.state_log, "volley_recover")
	assert_true(advance >= 0.0 and windup > advance and recover > windup, "advance -> windup -> volley; log=%s" % [p.state_log])
	assert_near(recover - windup, p.volley_windup_time, TIMING_TOLERANCE, "volley telegraph length")
	assert_true(windup - advance >= p.volley_cooldown - TIMING_TOLERANCE, "waits out the volley cooldown")
	assert_true(p.distance_to_target() >= p.advance_stop_range - 0.3, "stops short of the target")
	var dirs := p.shard_directions()
	assert_eq(dirs.size(), p.shard_count, "one direction per shard")
	assert_near(rad_to_deg(dirs[0].angle_to(dirs[dirs.size() - 1])), p.shard_spread_deg, 0.1, "fan spans the spread")
	await wait_seconds(1.0)
	assert_eq(dummy.hits.size(), 1, "only the centre shard hits a stationary target")
	assert_near(dummy.damage_taken(), p.shard_damage, 0.01, "shard damage")
	await wait_seconds(ScaleShard.MAX_RANGE / p.shard_speed)
	assert_eq(get_tree().get_nodes_in_group(LobProjectile.GROUP).size(), 0, "shards gone after flight")


func test_shard_passes_a_dodging_target() -> void:
	add_floor()
	var dodger := add_dummy_target(Vector3(0, 0, -4))
	var behind := add_dummy_target(Vector3(0, 0, -8))
	dodger.hurt_box.invulnerable = true
	var p := spawn_enemy(PANGOLIN, Vector3(0, 0, 20)) as BrassPangolin
	p.set_physics_process(false)
	await wait_frames(2)
	ScaleShard.launch(p, Vector3(0, 0.8, 0), Vector3.FORWARD, 15.0, 8.0)
	await wait_seconds(0.8)
	assert_eq(dodger.hits.size(), 0, "dodging target untouched")
	assert_eq(behind.hits.size(), 1, "shard flew on to the next target")


func test_roll_hits_then_uncurls() -> void:
	add_floor()
	var dummy := add_dummy_target(Vector3.ZERO)
	var p := spawn_enemy(PANGOLIN, Vector3(0, 0, -5), PI) as BrassPangolin
	var reached := await wait_until(func() -> bool: return p.state == &"uncurl", 4.0)
	assert_true(reached, "roll hit and uncurled; log=%s" % [p.state_log])
	var curl := state_time_in_log(p.state_log, "curl")
	var roll := state_time_in_log(p.state_log, "roll")
	assert_near(roll - curl, p.curl_time, TIMING_TOLERANCE, "curl telegraph length")
	assert_eq(dummy.hits.size(), 1, "roll hits once")
	assert_near(dummy.damage_taken(), p.roll_damage, 0.01, "roll damage")
	assert_true(p.is_guarding(), "a roll that hits leaves the armour up")
	assert_true(state_time_in_log(p.state_log, "dizzy") < 0.0, "no dizzy after a hit")


func test_roll_into_wall_bounces_then_dizzy_belly() -> void:
	add_floor()
	var dummy := add_dummy_target(Vector3.ZERO)
	add_wall(Vector3(0, 1.5, -3), Vector3(12, 3, 1))
	var p := spawn_enemy(PANGOLIN, Vector3(0, 0, -5.5), PI) as BrassPangolin
	var dizzy := await wait_until(func() -> bool: return p.state == &"dizzy", 5.0)
	assert_true(dizzy, "roll ended dizzy; log=%s" % [p.state_log])
	assert_true(p.bounces >= 1, "bounced off the wall")
	assert_eq(dummy.hits.size(), 0, "dummy behind the wall untouched")
	assert_false(p.is_guarding(), "armour down while dizzy")
	await wait_frames(2)
	var info := DamageInfo.create(10.0, p.global_position + p.forward() * 4.0)
	var before := p.health.current
	assert_true(p.belly.receive(info), "belly open while dizzy")
	assert_true(info.is_critical, "belly hits crit")
	assert_near(before - p.health.current, 10.0 * p.belly_multiplier, 0.01, "belly multiplier, no armour")
	var back := await wait_until(func() -> bool: return p.state == &"advance", p.dizzy_time + 0.5)
	assert_true(back, "gets back up")
	await wait_frames(2)
	assert_false(p.belly.receive(DamageInfo.create(10.0, Vector3.ZERO)), "belly closed again")
