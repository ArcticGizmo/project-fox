extends TestCase
## Furnace Stag (boss): phases by health with a roar, phase-1 guard, each attack
## pattern, the jumpable shockwave, toppling from a stomp wind-up, the boss bar.

const STAG := "res://scenes/enemies/furnace_stag.tscn"
const LEVEL := "res://scenes/levels/boss_furnace_stag.tscn"
const TIMING_TOLERANCE := 0.04


func _stag(at: Vector3 = Vector3(0, 0, -10), yaw: float = PI) -> FurnaceStag:
	return spawn_enemy(STAG, at, yaw) as FurnaceStag


func _hurt_to(s: FurnaceStag, fraction: float) -> void:
	s.health.apply_damage(DamageInfo.create(s.health.current - s.health.max_health * fraction, s.global_position))


func test_phases_follow_health_with_a_roar() -> void:
	add_floor()
	add_dummy_target(Vector3.ZERO)
	var s := _stag()
	var phases: Array[int] = []
	s.phase_changed.connect(func(p: int) -> void: phases.append(p))
	await wait_frames(2)
	assert_eq(s.phase, 1, "starts armoured")
	assert_false(s.furnace.monitorable, "furnace shut in phase 1")
	_hurt_to(s, 0.6)
	await wait_frames(2)
	assert_eq(s.state, &"roar", "roars at the threshold")
	var before := s.health.current
	assert_false(s.hurt_box.receive(DamageInfo.create(50.0, Vector3.ZERO)), "no damage while roaring")
	assert_eq(s.health.current, before, "health unchanged")
	await wait_seconds(s.roar_time + 0.1)
	assert_eq(s.phase, 2, "phase 2 after the roar")
	assert_true(s.furnace.monitorable, "furnace open")
	_hurt_to(s, 0.3)
	await wait_seconds(s.roar_time + 0.2)
	assert_eq(s.phase, 3, "phase 3")
	assert_eq(phases, [2, 3] as Array[int], "phase_changed for each")


func test_phase_one_guard_turns_frontal_hits() -> void:
	add_floor()
	var s := _stag(Vector3.ZERO, 0.0)
	s.set_physics_process(false)
	await wait_frames(2)
	var front := s.global_position + s.forward() * 5.0
	var back := s.global_position - s.forward() * 5.0
	var hp := s.health.current
	s.hurt_box.receive(DamageInfo.create(10.0, front))
	assert_near(hp - s.health.current, 10.0 * s.guard_factor, 0.01, "front guarded")
	hp = s.health.current
	s.hurt_box.receive(DamageInfo.create(10.0, back))
	assert_near(hp - s.health.current, 10.0, 0.01, "back open")
	hp = s.health.current
	s.vent.receive(DamageInfo.create(10.0, back))
	assert_near(hp - s.health.current, 10.0 * s.vent_multiplier, 0.01, "vent is a weak spot")


func test_sweep_up_close() -> void:
	add_floor()
	var dummy := add_dummy_target(Vector3.ZERO)
	var s := _stag(Vector3(0, 0, -6))
	var swept := await wait_until(func() -> bool: return s.state == &"recover", 5.0)
	assert_true(swept, "swept; log=%s" % [s.state_log])
	assert_eq(s.attack_log[0], &"sweep", "close range opens with the sweep")
	var windup := state_time_in_log(s.state_log, "sweep_windup")
	var sweep := state_time_in_log(s.state_log, "sweep")
	assert_near(sweep - windup, s.sweep_windup_time * s.pace(), TIMING_TOLERANCE, "sweep telegraph length")
	assert_eq(dummy.hits.size(), 1, "sweep hits once")
	assert_near(dummy.damage_taken(), s.sweep_damage, 0.01, "sweep damage")


func test_stomp_shockwave_is_jumped() -> void:
	add_floor()
	var grounded := add_dummy_target(Vector3(0, 0, 8))
	var airborne := add_dummy_target(Vector3(8, 1.2, 0))  # mid-jump at the same range
	var s := _stag(Vector3.ZERO, 0.0)
	await wait_frames(1)
	s.force_attack(&"stomp")
	var stomped := await wait_until(func() -> bool: return s.last_shockwave != null, 3.0)
	assert_true(stomped, "stomped; log=%s" % [s.state_log])
	assert_near(state_time_in_log(s.state_log, "stomp") - state_time_in_log(s.state_log, "stomp_windup"), s.stomp_windup_time * s.pace(), TIMING_TOLERANCE, "rear-up telegraph length")
	await wait_seconds(10.0 / s.shockwave_speed + 0.2)
	assert_eq(grounded.hits.size(), 1, "grounded target hit once")
	assert_near(grounded.damage_taken(), s.shockwave_damage, 0.01, "shockwave damage")
	assert_eq(airborne.hits.size(), 0, "a jump clears the ring")


func test_beetle_upend_topples_only_while_rearing() -> void:
	add_floor()
	add_dummy_target(Vector3(0, 0, 10))
	var s := _stag(Vector3.ZERO, 0.0)
	await wait_frames(2)
	s.upend(1.0)
	assert_ne_state(s, &"toppled", "too heavy to upend normally")
	s.force_attack(&"stomp")
	await wait_frames(2)
	assert_eq(s.state, &"stomp_windup", "rearing")
	s.upend(1.0)
	assert_eq(s.state, &"toppled", "knocked over mid-rear")
	assert_true(s.is_exposed(), "exposed while toppled")
	await wait_seconds(s.toppled_time + 0.1)
	assert_eq(s.state, &"stalk", "gets back up")
	assert_true(s.last_shockwave == null, "the stomp never landed")


func assert_ne_state(s: FurnaceStag, st: StringName, message: String) -> void:
	assert_true(s.state != st, "%s (state %s)" % [message, s.state])


func test_barrage_lobs_around_the_target() -> void:
	add_floor()
	add_dummy_target(Vector3.ZERO)
	var s := _stag(Vector3(0, 0, -14))
	await wait_frames(1)
	s.phase = 2
	s.force_attack(&"barrage")
	var fired := await wait_until(func() -> bool: return s.state == &"recover", 3.0)
	assert_true(fired, "barrage fired; log=%s" % [s.state_log])
	assert_eq(get_tree().get_nodes_in_group(LobProjectile.GROUP).size(), s.barrage_count, "one lob per barrage shot")


func test_charge_into_a_pillar_stuns() -> void:
	add_floor()
	add_dummy_target(Vector3.ZERO)
	add_wall(Vector3(0, 2, -6), Vector3(12, 4, 1.5))
	var s := _stag(Vector3(0, 0, -15))
	await wait_frames(1)
	s.phase = 2
	s.force_attack(&"charge")
	var stunned := await wait_until(func() -> bool: return s.state == &"stunned", 4.0)
	assert_true(stunned, "charged into the wall; log=%s" % [s.state_log])
	assert_false(s.is_guarding(), "no guard while stunned")


func test_lightning_marks_then_strikes() -> void:
	add_floor()
	var dummy := add_dummy_target(Vector3.ZERO)
	var s := _stag(Vector3(0, 0, -14))
	await wait_frames(1)
	s.phase = 3
	s.force_attack(&"strike")
	var called := await wait_until(func() -> bool: return s.last_strikes.size() == s.strike_count, 3.0)
	assert_true(called, "lightning called; log=%s" % [s.state_log])
	assert_eq(dummy.hits.size(), 0, "nothing strikes before the delay")
	await wait_seconds(s.strike_delay + 0.1)
	assert_true(dummy.damage_taken() >= s.strike_damage - 0.01, "the marked spot struck (%.1f)" % dummy.damage_taken())


func test_attacks_unlock_by_phase() -> void:
	add_floor()
	add_dummy_target(Vector3.ZERO)
	var s := _stag(Vector3(0, 0, -16))
	await wait_frames(2)
	var seen := {}
	for _i: int in 40:
		seen[s.call(&"_next_attack")] = true
	assert_true(seen.has(&"stomp") and not seen.has(&"barrage") and not seen.has(&"strike"), "phase 1: stomp only at range (%s)" % [seen.keys()])
	s.phase = 3
	seen.clear()
	for _i: int in 60:
		var a: StringName = s.call(&"_next_attack")
		seen[a] = true
		s.set(&"_last_attack", a)
	for a: StringName in [&"stomp", &"barrage", &"charge", &"strike"]:
		assert_true(seen.has(a), "phase 3 uses %s (%s)" % [a, seen.keys()])


func test_boss_bar_shows_name_and_phase() -> void:
	add_floor()
	var player := Player.new()
	player.input_provider = ScriptedInputProvider.new()
	player.position = Vector3(0, 0.05, 0)
	add_child(player)
	var hud := Hud.new()
	add_child(hud)
	await wait_frames(2)
	hud.bind(player, null)
	var s := spawn_enemy(STAG, Vector3(0, 0, -20), PI, 1, false) as FurnaceStag
	await wait_frames(2)
	assert_true(hud.current_boss() == null, "no bar before it notices you")
	s.become_aware()
	await wait_frames(2)
	assert_eq(hud.current_boss(), s, "bar tracks the boss")
	var label := hud.get(&"_boss_label") as Label
	assert_true(label.text.contains(s.display_name) and label.text.contains("Armoured"), "name and phase: %s" % label.text)


func test_boss_level_loads() -> void:
	var level := (load(LEVEL) as PackedScene).instantiate() as LevelRoot
	add_child(level)
	await wait_frames(3)
	var bosses := get_tree().get_nodes_in_group(&"bosses")
	assert_eq(bosses.size(), 1, "one boss")
	assert_true(level.player != null, "player built")
	assert_true(level.player.global_position.distance_to((bosses[0] as Node3D).global_position) > 20.0, "player starts well away from the stag")
	assert_true(LevelRoot.available_levels().has(LEVEL), "listed in level select")
	level.queue_free()
	await wait_frames(2)
